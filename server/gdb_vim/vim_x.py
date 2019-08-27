from __future__ import (absolute_import, division, print_function)

from os import path
import logging
import json

__metaclass__ = type  # pylint: disable=invalid-name


class VimX:

    def __init__(self, ch_in, ch_out):
        self.ch_in = ch_in
        self.ch_out = ch_out
        self.counter = -1
        self.buffer = [] # buffer for 'positive' objects
        self.logger = logging.getLogger(__name__)
        self.buffer_cache = {}

    def wait(self, expect=0):
        """ Blocking function. Use with care!
            `expect` should either be 0 or a negative number. If `expect == 0`, any positive
            indexed object is returned. Otherwise, it will queue any positive objects until the
            first negative object is received. If the received negative object does not match
            `expect`, then a ValueError is raised.
        """
        if expect > 0:
            raise AssertionError('expect <= 0')

        if expect == 0 and len(self.buffer) > 0:
            return self.buffer.pop()

        while True:
            s = self.ch_in.readline()

            ind, obj = json.loads(s)
            self.logger.info("recv %6d %s", ind, str(obj))

            if (expect == 0 and ind < 0):
                raise ValueError('Incorrect index received! {} != {}', expect, ind)

            elif expect < 0 and ind > 0:
                self.buffer.insert(0, obj)

            else:
                break

        return obj


    def _send(self, obj):
        s = json.dumps(obj)
        print(s, file=self.ch_out)
        self.ch_out.flush()


    def send_cmd(self, cmd, expr, *args, reply=True):
        """
        This function is used to send a command to VIM. If a reply is needed
        then a new expected number will be generated using self.counter and the
        reply is waited for and returned.
        """

        obj = [cmd, expr]

        if args:
            obj += args

        if reply:
            self.counter -= 1
            obj += [self.counter]

        self._send(obj)

        if reply:
            self.logger.info("%-6s %4d %s", cmd, self.counter, str([expr, args]))
            return self.wait(expect=self.counter)
        else:
            self.logger.info("%-6s      %s", cmd, str([expr, args]))


    def log(self, msg, level=1):
        """ Execute echom in vim using appropriate highlighting. """
        level_map = ['None', 'WarningMsg', 'ErrorMsg']
        msg = msg.strip().replace('"', '\\"').replace('\n', '\\n')
        self.send_cmd("ex", 'echohl {} | echom "{}" | echohl None'.format(level_map[level], msg), reply=False)

    def buffer_add(self, name):
        """ Create a buffer (if it doesn't exist) and return its number. """
        bufnr = self.send_cmd("call", 'bufnr', name, 1)
        self.send_cmd("call", 'setbufvar', bufnr, '&bl', 1, reply=False)
        return bufnr

    def buffer_scroll_bottom(self, bufnr):
        """ Scroll to bottom for every window that displays the given buffer in the current tab """
        self.send_cmd("call", 'gdb#util#buffer_do', bufnr, 'normal! G', reply=False)

    def sign_jump(self, bufnr, sign_id):
        """ Try jumping to the specified sign_id in buffer with number bufnr. """
        self.send_cmd("call", 'gdb#layout#signjump', bufnr, sign_id, reply=False)

    def sign_place(self, sign_id, name, bufnr, line):
        """ Place a sign at the specified location. """
        self.send_cmd("ex", "sign place {} name={} line={} buffer={}".format(sign_id, name, line, bufnr))

    def sign_unplace(self, sign_id):
        """ Hide a sign with specified id. """
        self.send_cmd("ex", "sign unplace {}".format(sign_id), reply=False)

    def get_buffer_name(self, nr): # FIXME?
        """ Get the buffer name given its number. """
        return self.send_cmd("call", 'bufname', nr)

    def abspath(self, relpath):
        vim_cwd = self.send_cmd("call", "getcwd")
        return path.join(vim_cwd, relpath)

    def init_buffers(self):
        """ Create all gdb buffers and initialize the buffer map. """
        return self.send_cmd("call", 'gdb#layout#init_buffers')

    def update_noma_buffer(self, bufnr, content):  # noma => nomodifiable
        has_mod = True
        if bufnr in self.buffer_cache \
                and len(content) == len(self.buffer_cache[bufnr]):
            has_mod = False
            for l1, l2 in zip(content, self.buffer_cache[bufnr]):
                if l1 != l2:
                    has_mod = True
                    break

        if has_mod:
            self.send_cmd("call", 'gdb#layout#update_buffer', bufnr, content, reply=False)
