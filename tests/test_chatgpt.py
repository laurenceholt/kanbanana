"""Synthetic catalog fixtures: never read the developer's actual chat history."""
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[1] / 'Resources'))
from kanbanana_reader import adapters, chatgpt, worker

class ChatGPTTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        (root / 'sqlite').mkdir()
        self.path = root / 'sqlite/codex.db'
        self.con = sqlite3.connect(self.path)
        self.addCleanup(self.con.close)
        self.con.executescript('''
          CREATE TABLE local_thread_catalog (host_id TEXT,thread_id TEXT,display_title TEXT,
            source_kind TEXT,source_updated_at REAL,missing_candidate INTEGER,chatgpt_async_status INTEGER);
          CREATE TABLE active_chat_turns (account_id TEXT,user_id TEXT,thread_id TEXT,observed_at_ms INTEGER);
        ''')
        self.now = time.time()
        p = patch.object(adapters, 'CODEX_HOME', root)
        p.start(); self.addCleanup(p.stop)
        self.id = '550e8400-e29b-41d4-a716-446655440000'

    def row(self, status=None, age=0, source='chatgpt', missing=0, host='chatgpt:account:user'):
        self.con.execute('INSERT INTO local_thread_catalog VALUES (?,?,?,?,?,?,?)',
            (host,self.id,'Example conversation',source,self.now-age,missing,status))
        self.con.commit()

    def test_null_status_does_not_mean_completed_and_no_fabricated_messages(self):
        self.row()
        result = adapters.scan_provider('chatgpt')
        card = result['cards'][0]
        self.assertEqual(card['state'], 'unknown')
        self.assertEqual(card['requests'], [])
        self.assertEqual(card['response'], '')
        self.assertFalse(result['inventoryComplete'])
        self.assertEqual(card['url'], 'https://chatgpt.com/c/' + self.id)
        self.assertEqual(result['health']['status'], 'connected')

    def test_explicit_unread_result_is_ready_and_streaming_expires(self):
        self.row(4)
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'ready')
        self.con.execute('UPDATE local_thread_catalog SET chatgpt_async_status=3'); self.con.commit()
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'running')
        self.con.execute('UPDATE local_thread_catalog SET source_updated_at=?',(self.now-300,)); self.con.commit()
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'unknown')

    def test_live_heartbeat_overrides_stale_unread_but_not_another_account(self):
        self.row(4, age=300)
        self.con.execute('INSERT INTO active_chat_turns VALUES (?,?,?,?)',('other','user',self.id,self.now*1000));self.con.commit()
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'ready')
        self.con.execute("UPDATE active_chat_turns SET account_id='account'");self.con.commit()
        first=chatgpt.cards(0)[0]
        self.assertEqual(first['state'], 'running')
        self.con.execute('UPDATE active_chat_turns SET observed_at_ms=?',((self.now-2)*1000,));self.con.commit()
        self.assertEqual(chatgpt.cards(0)[0]['eventID'], first['eventID'])
        self.con.execute('UPDATE active_chat_turns SET observed_at_ms=?',((self.now-60)*1000,));self.con.commit()
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'unknown')

    def test_old_tracked_cards_retained_catalog_absence_not_authoritative(self):
        self.row(age=20*86400)
        self.assertEqual(chatgpt.cards(self.now-14*86400), [])
        self.assertEqual(len(chatgpt.cards(self.now-14*86400, {'chatgpt:'+self.id})), 1)
        self.con.execute('DELETE FROM local_thread_catalog');self.con.commit()
        result=adapters.scan_provider('chatgpt')
        self.assertFalse(result['inventoryComplete'])

    def test_other_sources_missing_entries_and_unknown_status_never_ready(self):
        self.row(4,source='vscode');self.row(4,missing=1)
        self.assertEqual(chatgpt.cards(0), [])
        self.row(999)
        self.assertEqual(chatgpt.cards(0)[0]['state'], 'unknown')
        self.row(999,host='chatgpt:other:user')
        self.assertEqual(len(chatgpt.cards(0)), 1)

    def test_optional_heartbeat_table_and_schema_failure(self):
        self.row()
        self.con.execute('DROP TABLE active_chat_turns');self.con.commit()
        self.assertEqual(len(chatgpt.cards(0)), 1)
        self.con.execute('DROP TABLE local_thread_catalog');self.con.commit()
        result=adapters.scan_provider('chatgpt')
        self.assertEqual(result['health']['status'], 'unsupported')
        self.assertFalse(result['inventoryComplete'])

    def test_delta_protocol_and_disabled_provider(self):
        self.row(4)
        result=adapters.scan_provider('chatgpt')
        encoder=worker.DeltaEncoder('chatgpt')
        first=list(encoder.frames(result))
        self.assertEqual(first[0]['provider'],'chatgpt')
        self.assertEqual(first[0]['cards'][0]['state'],'ready')
        self.assertEqual(len(list(encoder.frames(result))),1)
        with patch.object(adapters,'DISABLED_PROVIDERS',{'chatgpt'}):
            self.assertEqual(adapters.scan_provider('chatgpt')['health']['status'],'disabled')

if __name__ == '__main__': unittest.main()
