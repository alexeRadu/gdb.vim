import logging
from gdb_vim.vim_x import VimX
from gdb_vim import Middleman
import sys

def main():
    vimx = VimX(sys.stdin, sys.stdout)

    try:
        print("Initializing...", file=sys.stderr)

        sys.stderr.flush()
        Middleman(vimx).loop()
    except:
        import time, traceback
        traceback.print_exc() # print traceback to stderr
    finally:
        print("Exited!", file=sys.stderr)
        sys.stderr.flush()
        time.sleep(2) # hope for vim to read

if __name__ == '__main__':
    handler = logging.FileHandler('/tmp/gdb.vim.log', 'w')
    handler.formatter = logging.Formatter(
        '%(msecs)6d %(levelname)-5s '
        '%(message)s')
    logging.root.addHandler(handler)
    logging.root.setLevel(logging.DEBUG)

    main()
