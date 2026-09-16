"""Launch the bundled read-only worker under Python's isolated mode."""
from pathlib import Path
import sys

# -I excludes the script directory. Add only our resolved resource directory,
# never the working directory or a user-controlled Python search path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kanbanana_reader.worker import main

if __name__ == "__main__":
    raise SystemExit(main())
