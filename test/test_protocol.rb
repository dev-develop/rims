# -*- coding: utf-8 -*-

require 'logger'
require 'rims'
require 'stringio'
require 'test/unit'
require 'time'

module RIMS::Test
  class TimeTest < Test::Unit::TestCase
    def test_parse_date_time
      assert_equal(Time.utc(1975, 11, 19, 3, 34, 56), Time.parse('19-Nov-1975 12:34:56 +0900'))
      assert_raise(ArgumentError) { Time.parse('detarame') }
      assert_raise(TypeError) { Time.parse([]) }
      assert_raise(TypeError) { Time.parse(nil) }
    end
  end

  class ProtocolTest < Test::Unit::TestCase
    def test_quote
      assert_equal('""', RIMS::Protocol.quote(''))
      assert_equal('"foo"', RIMS::Protocol.quote('foo'))
      assert_equal("{1}\r\n\"", RIMS::Protocol.quote('"'))
      assert_equal("{8}\r\nfoo\nbar\n", RIMS::Protocol.quote("foo\nbar\n"))
    end

    def test_compile_wildcard
      assert(RIMS::Protocol.compile_wildcard('xxx') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('xxx') !~ 'yyy')
      assert(RIMS::Protocol.compile_wildcard('x*') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('x*') !~ 'yxx')
      assert(RIMS::Protocol.compile_wildcard('*x') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('*x') !~ 'xxy')
      assert(RIMS::Protocol.compile_wildcard('*x*') =~ 'xyy')
      assert(RIMS::Protocol.compile_wildcard('*x*') =~ 'yxy')
      assert(RIMS::Protocol.compile_wildcard('*x*') =~ 'yyx')
      assert(RIMS::Protocol.compile_wildcard('*x*') !~ 'yyy')

      assert(RIMS::Protocol.compile_wildcard('xxx') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('xxx') !~ 'yyy')
      assert(RIMS::Protocol.compile_wildcard('x%') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('x%') !~ 'yxx')
      assert(RIMS::Protocol.compile_wildcard('%x') =~ 'xxx')
      assert(RIMS::Protocol.compile_wildcard('%x') !~ 'xxy')
      assert(RIMS::Protocol.compile_wildcard('%x%') =~ 'xyy')
      assert(RIMS::Protocol.compile_wildcard('%x%') =~ 'yxy')
      assert(RIMS::Protocol.compile_wildcard('%x%') =~ 'yyx')
      assert(RIMS::Protocol.compile_wildcard('%x%') !~ 'yyy')
    end

    def test_scan_line
      assert_equal([], RIMS::Protocol.scan_line('', StringIO.new))
      assert_equal(%w[ abcd CAPABILITY ],
                   RIMS::Protocol.scan_line('abcd CAPABILITY', StringIO.new))
      assert_equal(%w[ abcd OK CAPABILITY completed ],
                   RIMS::Protocol.scan_line('abcd OK CAPABILITY completed', StringIO.new))
      assert_equal(%w[ * CAPABILITY IMAP4rev1 AUTH=KERBEROS_V4 ],
                   RIMS::Protocol.scan_line('* CAPABILITY IMAP4rev1 AUTH=KERBEROS_V4', StringIO.new))
      assert_equal(%w[ * 172 EXISTS ],
                   RIMS::Protocol.scan_line('* 172 EXISTS', StringIO.new))
      assert_equal(%w[ * OK [ UNSEEN 12 ] Message 12 is first unseen ],
                   RIMS::Protocol.scan_line('* OK [UNSEEN 12] Message 12 is first unseen', StringIO.new))
      assert_equal(%w[ * FLAGS ( \\Answered \\Flagged \\Deleted \\Seen \\Draft ) ],
                   RIMS::Protocol.scan_line('* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)', StringIO.new))
      assert_equal(%w[ * OK [ PERMANENTFLAGS ( \\Deleted \\Seen \\* ) ] Limited ],
                   RIMS::Protocol.scan_line('* OK [PERMANENTFLAGS (\Deleted \Seen \*)] Limited', StringIO.new))
      assert_equal([ 'A82', 'LIST', '', '*' ],
                   RIMS::Protocol.scan_line('A82 LIST "" *', StringIO.new))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', '/', 'foo' ],
                   RIMS::Protocol.scan_line('* LIST (\Noselect) "/" foo', StringIO.new))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', '/', 'foo [bar] (baz)' ],
                   RIMS::Protocol.scan_line('* LIST (\Noselect) "/" "foo [bar] (baz)"', StringIO.new))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', :NIL, '' ],
                   RIMS::Protocol.scan_line('* LIST (\Noselect) NIL ""', StringIO.new))
    end

    def test_scan_line_string_literal
      literal = <<-'EOF'
Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
From: Fred Foobar <foobar@Blurdybloop.COM>
Subject: afternoon meeting
To: mooch@owatagu.siam.edu
Message-Id: <B27397-0100000@Blurdybloop.COM>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; CHARSET=US-ASCII

Hello Joe, do you think we can meet at 3:30 tomorrow?
      EOF

      line = 'A003 APPEND saved-messages (\Seen) ' + "{#{literal.bytesize}}"
      input = StringIO.new(literal + "\n")

      assert_equal([ 'A003', 'APPEND', 'saved-messages', '(', '\Seen', ')', literal ],
                   RIMS::Protocol.scan_line(line, input))
      assert_equal('', input.read)
    end

    def test_read_line
      assert_nil(RIMS::Protocol.read_line(StringIO.new))
      assert_equal([], RIMS::Protocol.read_line(StringIO.new("\n")))
      assert_equal(%w[ abcd CAPABILITY ],
                   RIMS::Protocol.read_line(StringIO.new("abcd CAPABILITY\n")))
      assert_equal(%w[ abcd OK CAPABILITY completed ],
                   RIMS::Protocol.read_line(StringIO.new("abcd OK CAPABILITY completed\n")))
      assert_equal(%w[ * CAPABILITY IMAP4rev1 AUTH=KERBEROS_V4 ],
                   RIMS::Protocol.read_line(StringIO.new("* CAPABILITY IMAP4rev1 AUTH=KERBEROS_V4\n")))
      assert_equal(%w[ * 172 EXISTS ],
                   RIMS::Protocol.read_line(StringIO.new("* 172 EXISTS\n")))
      assert_equal(%w[ * OK [ UNSEEN 12 ] Message 12 is first unseen ],
                   RIMS::Protocol.read_line(StringIO.new("* OK [UNSEEN 12] Message 12 is first unseen\n")))
      assert_equal(%w[ * FLAGS ( \\Answered \\Flagged \\Deleted \\Seen \\Draft ) ],
                   RIMS::Protocol.read_line(StringIO.new("* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)\n")))
      assert_equal(%w[ * OK [ PERMANENTFLAGS ( \\Deleted \\Seen \\* ) ] Limited ],
                   RIMS::Protocol.read_line(StringIO.new("* OK [PERMANENTFLAGS (\\Deleted \\Seen \\*)] Limited\n")))
      assert_equal([ 'A82', 'LIST', '', '*' ],
                   RIMS::Protocol.read_line(StringIO.new("A82 LIST \"\" *\n")))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', '/', 'foo' ],
                   RIMS::Protocol.read_line(StringIO.new("* LIST (\\Noselect) \"/\" foo\n")))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', '/', 'foo [bar] (baz)' ],
                   RIMS::Protocol.read_line(StringIO.new("* LIST (\\Noselect) \"/\" \"foo [bar] (baz)\"")))
      assert_equal([ '*', 'LIST', '(', '\Noselect', ')', :NIL, '' ],
                   RIMS::Protocol.read_line(StringIO.new('* LIST (\Noselect) NIL ""')))
    end

    def test_read_line_string_literal
      literal = <<-'EOF'
Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
From: Fred Foobar <foobar@Blurdybloop.COM>
Subject: afternoon meeting
To: mooch@owatagu.siam.edu
Message-Id: <B27397-0100000@Blurdybloop.COM>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; CHARSET=US-ASCII

Hello Joe, do you think we can meet at 3:30 tomorrow?
      EOF

      input = StringIO.new("A003 APPEND saved-messages (\\Seen) {#{literal.bytesize}}\n" + literal + "\n")
      assert_equal([ 'A003', 'APPEND', 'saved-messages', '(', '\Seen', ')', literal ],
                   RIMS::Protocol.read_line(input))
      assert_equal('', input.read)
    end

    def test_read_line_string_literal_multi
      literal1 = <<-'EOF'
Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
From: Fred Foobar <foobar@Blurdybloop.COM>
Subject: afternoon meeting
To: mooch@owatagu.siam.edu
Message-Id: <B27397-0100000@Blurdybloop.COM>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; CHARSET=US-ASCII
      EOF

      literal2 = <<-'EOF'
Hello Joe, do you think we can meet at 3:30 tomorrow?
      EOF

      input = StringIO.new("* ({#{literal1.bytesize}}\n" + literal1 + " {#{literal2.bytesize}}\n" + literal2 + ")\n")
      assert_equal([ '*', '(', literal1, literal2, ')' ], RIMS::Protocol.read_line(input))
      assert_equal('', input.read)
    end

    def test_parse
      assert_equal([], RIMS::Protocol.parse([]))
      assert_equal(%w[ abcd CAPABILITY ],
                   RIMS::Protocol.parse(%w[ abcd CAPABILITY ]))
      assert_equal(%w[ abcd OK CAPABILITY completed ],
                   RIMS::Protocol.parse(%w[ abcd OK CAPABILITY completed ]))
      assert_equal([ '*', 'OK', [ :block, 'UNSEEN', '12' ], 'Message', '12', 'is', 'first', 'unseen' ],
                   RIMS::Protocol.parse(%w[ * OK [ UNSEEN 12 ] Message 12 is first unseen ]))
      assert_equal([ '*', 'FLAGS', [ :group,  '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ] ],
                   RIMS::Protocol.parse(%w[ * FLAGS ( \\Answered \\Flagged \\Deleted \\Seen \\Draft ) ]))
      assert_equal([ '*', 'OK', [ :block, 'PERMANENTFLAGS', [ :group, '\Deleted', '\Seen', '\*' ] ], 'Limited' ],
                   RIMS::Protocol.parse(%w[ * OK [ PERMANENTFLAGS ( \\Deleted \\Seen \\* ) ] Limited ]))
      assert_equal([ '*', 'LIST', [ :group, '\Noselect' ], :NIL, '' ],
                   RIMS::Protocol.parse([ '*', 'LIST', '(', '\Noselect', ')', :NIL, '' ]))
    end

    def test_read_command
      assert_nil(RIMS::Protocol.read_command(StringIO.new))
      assert_nil(RIMS::Protocol.read_command(StringIO.new("\n")))
      assert_nil(RIMS::Protocol.read_command(StringIO.new(" \t\n")))
      assert_equal(%w[ abcd CAPABILITY ],
                   RIMS::Protocol.read_command(StringIO.new("abcd CAPABILITY\n")))
      assert_equal(%w[ abcd CAPABILITY ],
                   RIMS::Protocol.read_command(StringIO.new("\n \n\t\nabcd CAPABILITY\n")))
      assert_equal(%w[ abcd OK CAPABILITY completed ],
                   RIMS::Protocol.read_command(StringIO.new("abcd OK CAPABILITY completed\n")))
      assert_equal([ 'A003', 'STORE', '2:4', '+FLAGS', [ :group, '\Deleted' ] ],
                   RIMS::Protocol.read_command(StringIO.new("A003 STORE 2:4 +FLAGS (\\Deleted)\n")))

      literal = <<-'EOF'
Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
From: Fred Foobar <foobar@Blurdybloop.COM>
Subject: afternoon meeting
To: mooch@owatagu.siam.edu
Message-Id: <B27397-0100000@Blurdybloop.COM>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; CHARSET=US-ASCII

Hello Joe, do you think we can meet at 3:30 tomorrow?
      EOF

      input = StringIO.new("A003 APPEND saved-messages (\\Seen) {#{literal.bytesize}}\n" + literal + "\n")
      assert_equal([ 'A003', 'APPEND', 'saved-messages', [ :group, '\Seen' ], literal ],
		   RIMS::Protocol.read_command(input))
    end
  end

  class ProtocolDecoderTest < Test::Unit::TestCase
    def setup
      @kv_store = {}
      @mail_store = RIMS::MailStore.new('foo') {|path|
        kvs = {}
        def kvs.sync
          self
        end
        def kvs.close
          self
        end
        RIMS::GDBM_KeyValueStore.new(@kv_store[path] = kvs)
      }
      @mail_store.open
      @inbox_id = @mail_store.add_mbox('INBOX')
      @logger = Logger.new(STDOUT)
      @logger.level = ($DEBUG) ? Logger::DEBUG : Logger::FATAL
      @decoder = RIMS::ProtocolDecoder.new(@mail_store, @logger)
      @decoder.username = 'foo'
      @decoder.password = 'open_sesame'
    end

    def teardown
      @mail_store.close
    end

    def test_capability
      res = @decoder.capability('T001').each
      assert_equal('* CAPABILITY IMAP4rev1', res.next)
      assert_equal('T001 OK CAPABILITY completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_logout
      res = @decoder.logout('T003').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T003 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_login
      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T001', 'foo', 'detarame').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.logout('T003').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T003 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
    end

    def test_select
      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.select('T001', 'INBOX').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.select('T003', 'INBOX').each
      assert_equal('* 0 EXISTS', res.next)
      assert_equal('* 0 RECENT', res.next)
      assert_equal('* [UNSEEN 0]', res.next)
      assert_equal('* [UIDVALIDITY 1]', res.next)
      assert_equal('* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)', res.next)
      assert_equal('T003 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.logout('T004').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T004 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)
    end

    def test_examine_not_implemented
      assert_equal(false, @decoder.auth?)

      res = @decoder.examine('T001', 'INBOX').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.examine('T003', 'INBOX').each
      assert_equal('T003 BAD not implemented', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_create
      assert_equal(false, @decoder.auth?)

      res = @decoder.create('T001', 'foo').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      assert_nil(@mail_store.mbox_id('foo'))
      res = @decoder.create('T003', 'foo').each
      assert_equal('T003 OK CREATE completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_not_nil(@mail_store.mbox_id('foo'))

      res = @decoder.create('T004', 'inbox').each
      assert_match(/^T004 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.logout('T005').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T005 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_delete
      @mail_store.add_mbox('foo')

      assert_equal(false, @decoder.auth?)

      res = @decoder.delete('T001', 'foo').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_not_nil(@mail_store.mbox_id('foo'))

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.delete('T003', 'foo').each
      assert_equal('T003 OK DELETE completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_nil(@mail_store.mbox_id('foo'))

      res = @decoder.delete('T004', 'bar').each
      assert_match(/^T004 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.delete('T005', 'inbox').each
      assert_match(/^T005 NO /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_not_nil(@mail_store.mbox_id('inbox'))

      res = @decoder.logout('T006').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T006 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_rename_not_implemented
      @mail_store.add_mbox('foo')
      assert_not_nil(@mail_store.mbox_id('foo'))
      assert_nil(@mail_store.mbox_id('bar'))

      assert_equal(false, @decoder.auth?)

      res = @decoder.rename('T001', 'foo', 'bar').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_not_nil(@mail_store.mbox_id('foo'))
      assert_nil(@mail_store.mbox_id('bar'))

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.rename('T003', 'foo', 'bar').each
      assert_equal('T003 BAD not implemented', res.next)
      assert_raise(StopIteration) { res.next }
      assert_not_nil(@mail_store.mbox_id('foo'))
      assert_nil(@mail_store.mbox_id('bar'))
    end

    def test_subscribe_not_implemented
      assert_equal(false, @decoder.auth?)

      res = @decoder.subscribe('T001', 'INBOX').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.subscribe('T003', 'INBOX').each
      assert_equal('T003 BAD not implemented', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_unsubscribe_not_implemented
      assert_equal(false, @decoder.auth?)

      res = @decoder.unsubscribe('T001', 'INBOX').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.unsubscribe('T003', 'INBOX').each
      assert_equal('T003 BAD not implemented', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_list
      assert_equal(false, @decoder.auth?)

      res = @decoder.list('T001', '', '').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.list('T003', '', '').each
      assert_equal('* LIST (\Noselect) NIL ""', res.next)
      assert_equal('T003 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.list('T004', '', 'nobox').each
      assert_equal('T004 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.list('T005', '', '*').each
      assert_equal('* LIST (\Noinferiors \Unmarked) NIL "INBOX"', res.next)
      assert_equal('T005 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.add_msg(@inbox_id, 'foo')

      res = @decoder.list('T006', '', '*').each
      assert_equal('* LIST (\Noinferiors \Marked) NIL "INBOX"', res.next)
      assert_equal('T006 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.add_mbox('foo')

      res = @decoder.list('T007', '', '*').each
      assert_equal('* LIST (\Noinferiors \Marked) NIL "INBOX"', res.next)
      assert_equal('* LIST (\Noinferiors \Unmarked) NIL "foo"', res.next)
      assert_equal('T007 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.list('T008', '', 'f*').each
      assert_equal('* LIST (\Noinferiors \Unmarked) NIL "foo"', res.next)
      assert_equal('T008 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.list('T009', 'IN', '*').each
      assert_equal('* LIST (\Noinferiors \Marked) NIL "INBOX"', res.next)
      assert_equal('T009 OK LIST completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.logout('T010').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T010 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_status
      assert_equal(false, @decoder.auth?)

      res = @decoder.status('T001', 'nobox', [ :group, 'MESSAGES' ]).each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.status('T003', 'nobox', [ :group, 'MESSAGES' ]).each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.status('T004', 'INBOX', [ :group, 'MESSAGES' ]).each
      assert_equal('* STATUS "INBOX" (MESSAGES 0)', res.next)
      assert_equal('T004 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.status('T005', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 0 RECENT 0 UINDEX 1 UIDVALIDITY #{@inbox_id} UNSEEN 0)", res.next)
      assert_equal('T005 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.add_msg(@inbox_id, 'foo')
      res = @decoder.status('T006', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 1 RECENT 1 UINDEX 2 UIDVALIDITY #{@inbox_id} UNSEEN 1)", res.next)
      assert_equal('T006 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.set_msg_flag(@inbox_id, 1, 'recent', false)
      res = @decoder.status('T007', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 1 RECENT 0 UINDEX 2 UIDVALIDITY #{@inbox_id} UNSEEN 1)", res.next)
      assert_equal('T007 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.set_msg_flag(@inbox_id, 1, 'seen', true)
      res = @decoder.status('T008', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 1 RECENT 0 UINDEX 2 UIDVALIDITY #{@inbox_id} UNSEEN 0)", res.next)
      assert_equal('T008 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.add_msg(@inbox_id, 'bar')
      res = @decoder.status('T009', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 2 RECENT 1 UINDEX 3 UIDVALIDITY #{@inbox_id} UNSEEN 1)", res.next)
      assert_equal('T009 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.set_msg_flag(@inbox_id, 2, 'deleted', true)
      @mail_store.expunge_mbox(@inbox_id)
      res = @decoder.status('T010', 'INBOX', [ :group, 'MESSAGES', 'RECENT', 'UINDEX', 'UIDVALIDITY', 'UNSEEN' ]).each
      assert_equal("* STATUS \"INBOX\" (MESSAGES 1 RECENT 0 UINDEX 3 UIDVALIDITY #{@inbox_id} UNSEEN 0)", res.next)
      assert_equal('T010 OK STATUS completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.status('T011', 'INBOX', 'MESSAGES').each
      assert_match(/^T011 BAD /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.status('T012', 'INBOX', [ :group, 'DETARAME' ]).each
      assert_match(/^T012 BAD /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.logout('T013').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T013 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_lsub_not_implemented
      assert_equal(false, @decoder.auth?)

      res = @decoder.lsub('T001', '', '').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.lsub('T003', '', '').each
      assert_equal('T003 BAD not implemented', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_append
      assert_equal(false, @decoder.auth?)

      res = @decoder.append('T001', 'INBOX', 'a').each
      assert_match(/^T001 NO /, res.peek)
      assert_no_match(/\[TRYCREATE\]/, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([], @mail_store.each_msg_id(@inbox_id).to_a)

      assert_equal(false, @decoder.auth?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)

      res = @decoder.append('T003', 'INBOX', 'a').each
      assert_equal('T003 OK APPEND completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal('a', @mail_store.msg_text(@inbox_id, 1))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 1, 'recent'))

      res = @decoder.append('T004', 'INBOX', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], 'b').each
      assert_equal('T004 OK APPEND completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal('b', @mail_store.msg_text(@inbox_id, 2))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'answered'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'flagged'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'deleted'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'seen'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'recent'))

      res = @decoder.append('T005', 'INBOX', '19-Nov-1975 12:34:56 +0900', 'c').each
      assert_equal('T005 OK APPEND completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal('c', @mail_store.msg_text(@inbox_id, 3))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'answered'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 3, 'recent'))
      assert_equal(Time.utc(1975, 11, 19, 3, 34, 56), @mail_store.msg_date(@inbox_id, 3))

      res = @decoder.append('T006', 'INBOX', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], '19-Nov-1975 12:34:56 +0900', 'd').each
      assert_equal('T006 OK APPEND completed', res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal('d', @mail_store.msg_text(@inbox_id, 4))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'answered'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'flagged'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'deleted'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'seen'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'recent'))
      assert_equal(Time.utc(1975, 11, 19, 3, 34, 56), @mail_store.msg_date(@inbox_id, 4))

      res = @decoder.append('T007', 'INBOX', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], '19-Nov-1975 12:34:56 +0900', :NIL, 'x').each
      assert_match(/^T007 BAD /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.append('T008', 'INBOX', '19-Nov-1975 12:34:56 +0900', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], 'x').each
      assert_match(/^T008 BAD /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.append('T009', 'INBOX', [ :group, '\Recent' ], 'x').each
      assert_match(/^T009 BAD /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.append('T010', 'INBOX', 'bad date-time', 'x').each
      assert_match(/^T010 BAD /, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.append('T011', 'nobox', 'x').each
      assert_match(/^T011 NO \[TRYCREATE\]/, res.next)
      assert_raise(StopIteration) { res.next }
      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.logout('T012').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T012 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_check
      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.check('T001').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.check('T003').each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.check('T005').each
      assert_equal('T005 OK CHECK completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.logout('T006').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T006 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_close
      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.close('T001').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.close('T003').each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.close('T005').each
      assert_equal('T005 OK CLOSE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      @mail_store.add_msg(@inbox_id, 'foo')
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T006', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T006 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.close('T007').each
      assert_equal('T007 OK CLOSE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T008', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T008 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'recent'))

      @mail_store.set_msg_flag(@inbox_id, 1, 'deleted', true)

      res = @decoder.close('T009').each
      assert_equal('T009 OK CLOSE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)
      assert_equal([], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.logout('T010').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T010 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_expunge
      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.expunge('T001').each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.expunge('T003').each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.expunge('T005').each
      assert_equal('T005 OK EXPUNGE completed', res.next)
      assert_raise(StopIteration) { res.next }

      @mail_store.add_msg(@inbox_id, 'a')
      @mail_store.add_msg(@inbox_id, 'b')
      @mail_store.add_msg(@inbox_id, 'c')
      assert_equal([ 1, 2, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)

      res = @decoder.expunge('T006').each
      assert_equal('T006 OK EXPUNGE completed', res.next)
      assert_raise(StopIteration) { res.next }

      for name in %w[ answered flagged seen draft ]
        @mail_store.set_msg_flag(@inbox_id, 2, name, true)
        @mail_store.set_msg_flag(@inbox_id, 3, name, true)
      end
      @mail_store.set_msg_flag(@inbox_id, 2, 'deleted', true)

      assert_equal([ 1, 2, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(3, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'deleted'))

      res = @decoder.expunge('T007').each
      assert_equal('* 2 EXPUNGE', res.next)
      assert_equal('T007 OK EXPUNGE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(2, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))

      @mail_store.set_msg_flag(@inbox_id, 1, 'deleted', true)
      @mail_store.set_msg_flag(@inbox_id, 3, 'deleted', true)
      
      assert_equal([ 1, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(2, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))

      res = @decoder.expunge('T008').each
      assert_equal('* 1 EXPUNGE', res.next)
      assert_equal('* 2 EXPUNGE', res.next)
      assert_equal('T008 OK EXPUNGE completed', res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.logout('T009').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T009 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_store
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end
      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T001', '1', '+FLAGS', [ :group, '\Answered' ]).each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T003', '1', '+FLAGS', [ :group, '\Answered' ]).each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.store('T005', '1', '+FLAGS', [ :group, '\Answered' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Recent)', res.next)
      assert_equal('T005 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))

      res = @decoder.store('T006', '1:2', '+FLAGS', [ :group, '\Flagged' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Recent)', res.next)
      assert_equal('T006 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T007', '1:3', '+FLAGS', [ :group, '\Deleted' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Recent)', res.next)
      assert_equal('T007 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T008', '1:4', '+FLAGS', [ :group, '\Seen' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Seen \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Seen \Recent)', res.next)
      assert_equal('T008 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T009', '1:5', '+FLAGS', [ :group, '\Draft' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Seen \Draft \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Draft \Recent)', res.next)
      assert_equal('T009 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T010', '1:*', 'FLAGS', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ]).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T010 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T011', '1', '-FLAGS', [ :group, '\Answered' ]).each
      assert_equal('* 1 FETCH FLAGS (\Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T011 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T012', '1:2', '-FLAGS', [ :group, '\Flagged' ]).each
      assert_equal('* 1 FETCH FLAGS (\Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T012 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T013', '1:3', '-FLAGS', [ :group, '\Deleted' ]).each
      assert_equal('* 1 FETCH FLAGS (\Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Seen \Draft \Recent)', res.next)
      assert_equal('T013 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T014', '1:4', '-FLAGS', [ :group, '\Seen' ]).each
      assert_equal('* 1 FETCH FLAGS (\Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Draft \Recent)', res.next)
      assert_equal('T014 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T015', '1:5', '-FLAGS', [ :group, '\Draft' ]).each
      assert_equal('* 1 FETCH FLAGS (\Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('T015 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.logout('T016').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T016 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_store_silent
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end
      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T001', '1', '+FLAGS.SILENT', [ :group, '\Answered' ]).each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T003', '1', '+FLAGS.SILENT', [ :group, '\Answered' ]).each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.store('T005', '1', '+FLAGS.SILENT', [ :group, '\Answered' ]).each
      assert_equal('T005 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))

      res = @decoder.store('T006', '1:2', '+FLAGS.SILENT', [ :group, '\Flagged' ]).each
      assert_equal('T006 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T007', '1:3', '+FLAGS.SILENT', [ :group, '\Deleted' ]).each
      assert_equal('T007 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T008', '1:4', '+FLAGS.SILENT', [ :group, '\Seen' ]).each
      assert_equal('T008 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T009', '1:5', '+FLAGS.SILENT', [ :group, '\Draft' ]).each
      assert_equal('T009 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T010', '1:*', 'FLAGS.SILENT', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ]).each
      assert_equal('T010 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T011', '1', '-FLAGS.SILENT', [ :group, '\Answered' ]).each
      assert_equal('T011 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T012', '1:2', '-FLAGS.SILENT', [ :group, '\Flagged' ]).each
      assert_equal('T012 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T013', '1:3', '-FLAGS.SILENT', [ :group, '\Deleted' ]).each
      assert_equal('T013 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T014', '1:4', '-FLAGS.SILENT', [ :group, '\Seen' ]).each
      assert_equal('T014 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T015', '1:5', '-FLAGS.SILENT', [ :group, '\Draft' ]).each
      assert_equal('T015 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.logout('T016').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T016 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_uid_store
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end
      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T001', '1', '+FLAGS', [ :group, '\Answered' ], uid: true).each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T003', '1', '+FLAGS', [ :group, '\Answered' ], uid: true).each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.store('T005', '1', '+FLAGS', [ :group, '\Answered' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Recent)', res.next)
      assert_equal('T005 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))

      res = @decoder.store('T006', '1,3', '+FLAGS', [ :group, '\Flagged' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Recent)', res.next)
      assert_equal('T006 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T007', '1,3,5', '+FLAGS', [ :group, '\Deleted' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Recent)', res.next)
      assert_equal('T007 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T008', '1,3,5,7', '+FLAGS', [ :group, '\Seen' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Seen \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Seen \Recent)', res.next)
      assert_equal('T008 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T009', '1,3,5,7,9', '+FLAGS', [ :group, '\Draft' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Seen \Draft \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Draft \Recent)', res.next)
      assert_equal('T009 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T010', '1:*', 'FLAGS', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T010 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T011', '1', '-FLAGS', [ :group, '\Answered' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Flagged \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T011 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T012', '1,3', '-FLAGS', [ :group, '\Flagged' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Deleted \Seen \Draft \Recent)', res.next)
      assert_equal('T012 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T013', '1,3,5', '-FLAGS', [ :group, '\Deleted' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Seen \Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Seen \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Seen \Draft \Recent)', res.next)
      assert_equal('T013 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T014', '1,3,5,7', '-FLAGS', [ :group, '\Seen' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Draft \Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Draft \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Draft \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Draft \Recent)', res.next)
      assert_equal('T014 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T015', '1,3,5,7,9', '-FLAGS', [ :group, '\Draft' ], uid: true).each
      assert_equal('* 1 FETCH FLAGS (\Recent)', res.next)
      assert_equal('* 2 FETCH FLAGS (\Answered \Recent)', res.next)
      assert_equal('* 3 FETCH FLAGS (\Answered \Flagged \Recent)', res.next)
      assert_equal('* 4 FETCH FLAGS (\Answered \Flagged \Deleted \Recent)', res.next)
      assert_equal('* 5 FETCH FLAGS (\Answered \Flagged \Deleted \Seen \Recent)', res.next)
      assert_equal('T015 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.logout('T016').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T016 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_uid_store_silent
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end
      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      assert_equal(false, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T001', '1', '+FLAGS.SILENT', [ :group, '\Answered' ], uid: true).each
      assert_match(/^T001 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      res = @decoder.login('T002', 'foo', 'open_sesame').each
      assert_equal('T002 OK LOGIN completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(false, @decoder.selected?)

      res = @decoder.store('T003', '1', '+FLAGS.SILENT', [ :group, '\Answered' ], uid: true).each
      assert_match(/^T003 NO /, res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.select('T004', 'INBOX').each
      res.next while (res.peek =~ /^\* /)
      assert_equal('T004 OK [READ-WRITE] SELECT completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal(true, @decoder.auth?)
      assert_equal(true, @decoder.selected?)

      res = @decoder.store('T005', '1', '+FLAGS.SILENT', [ :group, '\Answered' ], uid: true).each
      assert_equal('T005 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))

      res = @decoder.store('T006', '1,3', '+FLAGS.SILENT', [ :group, '\Flagged' ], uid: true).each
      assert_equal('T006 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T007', '1,3,5', '+FLAGS.SILENT', [ :group, '\Deleted' ], uid: true).each
      assert_equal('T007 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T008', '1,3,5,7', '+FLAGS.SILENT', [ :group, '\Seen' ], uid: true).each
      assert_equal('T008 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T009', '1,3,5,7,9', '+FLAGS.SILENT', [ :group, '\Draft' ], uid: true).each
      assert_equal('T009 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(@mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T010', '1:*', 'FLAGS.SILENT', [ :group, '\Answered', '\Flagged', '\Deleted', '\Seen', '\Draft' ], uid: true).each
      assert_equal('T010 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T011', '1', '-FLAGS.SILENT', [ :group, '\Answered' ], uid: true).each
      assert_equal('T011 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T012', '1,3', '-FLAGS.SILENT', [ :group, '\Flagged' ], uid: true).each
      assert_equal('T012 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T013', '1,3,5', '-FLAGS.SILENT', [ :group, '\Deleted' ], uid: true).each
      assert_equal('T013 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T014', '1,3,5,7', '-FLAGS.SILENT', [ :group, '\Seen' ], uid: true).each
      assert_equal('T014 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.store('T015', '1,3,5,7,9', '-FLAGS.SILENT', [ :group, '\Draft' ], uid: true).each
      assert_equal('T015 OK STORE completed', res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(4, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'deleted'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'seen'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 5, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 7, 'draft'))
      assert(! @mail_store.msg_flag(@inbox_id, 9, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      res = @decoder.logout('T016').each
      assert_match(/^\* BYE /, res.next)
      assert_equal('T016 OK LOGOUT completed', res.next)
      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_empty
      output = StringIO.new('', 'w')

      RIMS::ProtocolDecoder.repl(@decoder, StringIO.new('', 'r'), output, @logger)
      assert_equal('', output.string)

      RIMS::ProtocolDecoder.repl(@decoder, StringIO.new("\n\t\n \r\n ", 'r'), output, @logger)
      assert_equal('', output.string)
    end

    def test_command_loop_capability
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 CAPABILITY
T002 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_equal("* CAPABILITY IMAP4rev1\r\n", res.next)
      assert_equal("T001 OK CAPABILITY completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T002 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_login
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 LOGIN foo detarame
T002 LOGIN foo open_sesame
T003 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T003 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_select
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 SELECT INBOX
T002 LOGIN foo open_sesame
T003 SELECT INBOX
T004 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_equal("* 0 EXISTS\r\n", res.next)
      assert_equal("* 0 RECENT\r\n", res.next)
      assert_equal("* [UNSEEN 0]\r\n", res.next)
      assert_equal("* [UIDVALIDITY 1]\r\n", res.next)
      assert_equal("* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)\r\n", res.next)
      assert_equal("T003 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T004 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_create
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 CREATE foo
T002 LOGIN foo open_sesame
T003 CREATE foo
T004 CREATE inbox
T005 LOGOUT
      EOF

      assert_nil(@mail_store.mbox_id('foo'))
      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      assert_not_nil(@mail_store.mbox_id('foo'))
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_equal("T003 OK CREATE completed\r\n", res.next)

      assert_match(/^T004 NO /, res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T005 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_delete
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 DELETE foo
T002 LOGIN foo open_sesame
T003 DELETE foo
T004 DELETE bar
T005 DELETE inbox
T006 LOGOUT
      EOF

      @mail_store.add_mbox('foo')
      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      assert_nil(@mail_store.mbox_id('foo'))
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_equal("T003 OK DELETE completed\r\n", res.next)

      assert_match(/^T004 NO /, res.next)

      assert_match(/^T005 NO /, res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T006 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def _test_command_loop_list
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 LIST "" ""
T002 LOGIN foo open_sesame
T003 LIST "" ""
T007 LIST "" *
T008 LIST '' f*
T009 LIST IN *
T010 LOGOUT
      EOF

      @mail_store.add_msg(@inbox_id, 'foo')
      @mail_store.add_mbox('foo')
      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      assert_nil(@mail_store.mbox_id('foo'))
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_equal('* LIST (\Noselect) NIL ""' + "\r\n", res.next)
      assert_equal("T003 OK LIST completed\r\n", res.next)

      assert_equal('* LIST (\Noinferiors \Marked) NIL "INBOX"' + "\r\n", res.next)
      assert_equal('* LIST (\Noinferiors \Unmarked) NIL "foo"' + "\r\n", res.next)
      assert_equal("T007 OK LIST completed\r\n", res.next)

      assert_equal('* LIST (\Noinferiors \Unmarked) NIL "foo"' + "\r\n", res.next)
      assert_equal("T008 OK LIST completed\r\n", res.next)

      assert_equal('* LIST (\Noinferiors \Marked) NIL "INBOX"' + "\r\n", res.next)
      assert_equal("T009 OK LIST completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T010 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_status
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 STATUS nobox (MESSAGES)
T002 LOGIN foo open_sesame
T003 STATUS nobox (MESSAGES)
T009 STATUS INBOX (MESSAGES RECENT UINDEX UIDVALIDITY UNSEEN)
T011 STATUS INBOX MESSAGES
T012 STATUS INBOX (DETARAME)
T013 LOGOUT
      EOF

      @mail_store.add_msg(@inbox_id, 'foo')
      @mail_store.set_msg_flag(@inbox_id, 1, 'recent', false)
      @mail_store.set_msg_flag(@inbox_id, 1, 'seen', true)
      @mail_store.add_msg(@inbox_id, 'bar')

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      assert_nil(@mail_store.mbox_id('foo'))
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      assert_equal("* STATUS \"INBOX\" (MESSAGES 2 RECENT 1 UINDEX 3 UIDVALIDITY #{@inbox_id} UNSEEN 1)\r\n", res.next)
      assert_equal("T009 OK STATUS completed\r\n", res.next)

      assert_match(/^T011 BAD /, res.next)

      assert_match(/^T012 BAD /, res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T013 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_append
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 APPEND INBOX a
T002 LOGIN foo open_sesame
T003 APPEND INBOX a
T004 APPEND INBOX (\Answered \Flagged \Deleted \Seen \Draft) "b"
T005 APPEND INBOX "19-Nov-1975 12:34:56 +0900" {1}
c
T006 APPEND INBOX (\Answered \Flagged \Deleted \Seen \Draft) "19-Nov-1975 12:34:56 +0900" d
T007 APPEND INBOX (\Answered \Flagged \Deleted \Seen \Draft) "19-Nov-1975 12:34:56 +0900" NIL x
T008 APPEND INBOX "19-Nov-1975 12:34:56 +0900" (\Answered \Flagged \Deleted \Seen \Draft) x
T009 APPEND INBOX (\Recent) x
T010 APPEND INBOX "bad date-time" x
T011 APPEND nobox x
T012 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)
      assert_equal("T002 OK LOGIN completed\r\n", res.next)
      assert_equal("T003 OK APPEND completed\r\n", res.next)
      assert_equal("T004 OK APPEND completed\r\n", res.next)
      assert_equal("T005 OK APPEND completed\r\n", res.next)
      assert_equal("T006 OK APPEND completed\r\n", res.next)
      assert_match(/^T007 BAD /, res.next)
      assert_match(/^T008 BAD /, res.next)
      assert_match(/^T009 BAD /, res.next)
      assert_match(/^T010 BAD /, res.next)
      assert_match(/^T011 NO \[TRYCREATE\]/, res.next)
      assert_match(/^\* BYE /, res.next)
      assert_equal("T012 OK LOGOUT completed\r\n", res.next)
      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)

      assert_equal('a', @mail_store.msg_text(@inbox_id, 1))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'answered'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'flagged'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'deleted'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'seen'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 1, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 1, 'recent'))

      assert_equal('b', @mail_store.msg_text(@inbox_id, 2))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'answered'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'flagged'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'deleted'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'seen'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 2, 'recent'))

      assert_equal('c', @mail_store.msg_text(@inbox_id, 3))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'answered'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'flagged'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'deleted'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'seen'))
      assert_equal(false, @mail_store.msg_flag(@inbox_id, 3, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 3, 'recent'))
      assert_equal(Time.utc(1975, 11, 19, 3, 34, 56), @mail_store.msg_date(@inbox_id, 3))

      assert_equal([ 1, 2, 3, 4 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal('d', @mail_store.msg_text(@inbox_id, 4))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'answered'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'flagged'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'deleted'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'seen'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'draft'))
      assert_equal(true, @mail_store.msg_flag(@inbox_id, 4, 'recent'))
      assert_equal(Time.utc(1975, 11, 19, 3, 34, 56), @mail_store.msg_date(@inbox_id, 4))
    end

    def test_command_loop_check
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 CHECK
T002 LOGIN foo open_sesame
T003 CHECK
T004 SELECT INBOX
T005 CHECK
T006 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("T005 OK CHECK completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T006 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_close
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 CLOSE
T002 LOGIN foo open_sesame
T003 CLOSE
T006 SELECT INBOX
T007 CLOSE
T008 LOGOUT
      EOF

      @mail_store.add_msg(@inbox_id, 'foo')
      assert_equal([ 1 ], @mail_store.each_msg_id(@inbox_id).to_a)
      @mail_store.set_msg_flag(@inbox_id, 1, 'deleted', true)

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T006 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("T007 OK CLOSE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T008 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }

      assert_equal([], @mail_store.each_msg_id(@inbox_id).to_a)
    end

    def test_command_loop_expunge
      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 EXPUNGE
T002 LOGIN foo open_sesame
T003 EXPUNGE
T004 SELECT INBOX
T007 EXPUNGE
T009 LOGOUT
      EOF

      @mail_store.add_msg(@inbox_id, 'a')
      @mail_store.add_msg(@inbox_id, 'b')
      @mail_store.add_msg(@inbox_id, 'c')
      for name in %w[ answered flagged seen draft ]
        @mail_store.set_msg_flag(@inbox_id, 2, name, true)
        @mail_store.set_msg_flag(@inbox_id, 3, name, true)
      end
      @mail_store.set_msg_flag(@inbox_id, 2, 'deleted', true)

      assert_equal([ 1, 2, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(3, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(3, @mail_store.mbox_flags(@inbox_id, 'recent'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(2, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'deleted'))

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("* 2 EXPUNGE\r\n", res.next)
      assert_equal("T007 OK EXPUNGE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T009 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }

      assert_equal([ 1, 3 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(2, @mail_store.mbox_msgs(@inbox_id))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'recent')) # clear by LOGOUT
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(1, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
    end

    def test_command_loop_store
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end

      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 STORE 1 +FLAGS (\Answered)
T002 LOGIN foo open_sesame
T003 STORE 1 +FLAGS (\Answered)
T004 SELECT INBOX
T005 STORE 1 +FLAGS (\Answered)
T006 STORE 1:2 +FLAGS (\Flagged)
T007 STORE 1:3 +FLAGS (\Deleted)
T008 STORE 1:4 +FLAGS (\Seen)
T009 STORE 1:5 +FLAGS (\Draft)
T010 STORE 1:* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
T011 STORE 1 -FLAGS (\Answered)
T012 STORE 1:2 -FLAGS (\Flagged)
T013 STORE 1:3 -FLAGS (\Deleted)
T014 STORE 1:4 -FLAGS (\Seen)
T015 STORE 1:5 -FLAGS (\Draft)
T016 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Recent)\r\n", res.next)
      assert_equal("T005 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Recent)\r\n", res.next)
      assert_equal("T006 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Recent)\r\n", res.next)
      assert_equal("T007 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Seen \\Recent)\r\n", res.next)
      assert_equal("T008 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Draft \\Recent)\r\n", res.next)
      assert_equal("T009 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T010 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T011 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T012 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T013 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Draft \\Recent)\r\n", res.next)
      assert_equal("T014 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("T015 OK STORE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T016 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_store_silent
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end

      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 STORE 1 +FLAGS.SILENT (\Answered)
T002 LOGIN foo open_sesame
T003 STORE 1 +FLAGS.SILENT (\Answered)
T004 SELECT INBOX
T005 STORE 1 +FLAGS.SILENT (\Answered)
T006 STORE 1:2 +FLAGS.SILENT (\Flagged)
T007 STORE 1:3 +FLAGS.SILENT (\Deleted)
T008 STORE 1:4 +FLAGS.SILENT (\Seen)
T009 STORE 1:5 +FLAGS.SILENT (\Draft)
T010 STORE 1:* FLAGS.SILENT (\Answered \Flagged \Deleted \Seen \Draft)
T011 STORE 1 -FLAGS.SILENT (\Answered)
T012 STORE 1:2 -FLAGS.SILENT (\Flagged)
T013 STORE 1:3 -FLAGS.SILENT (\Deleted)
T014 STORE 1:4 -FLAGS.SILENT (\Seen)
T015 STORE 1:5 -FLAGS.SILENT (\Draft)
T016 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("T005 OK STORE completed\r\n", res.next)

      assert_equal("T006 OK STORE completed\r\n", res.next)

      assert_equal("T007 OK STORE completed\r\n", res.next)

      assert_equal("T008 OK STORE completed\r\n", res.next)

      assert_equal("T009 OK STORE completed\r\n", res.next)

      assert_equal("T010 OK STORE completed\r\n", res.next)

      assert_equal("T011 OK STORE completed\r\n", res.next)

      assert_equal("T012 OK STORE completed\r\n", res.next)

      assert_equal("T013 OK STORE completed\r\n", res.next)

      assert_equal("T014 OK STORE completed\r\n", res.next)

      assert_equal("T015 OK STORE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T016 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_uid_store
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end

      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 UID STORE 1 +FLAGS (\Answered)
T002 LOGIN foo open_sesame
T003 UID STORE 1 +FLAGS (\Answered)
T004 SELECT INBOX
T005 UID STORE 1 +FLAGS (\Answered)
T006 UID STORE 1,3 +FLAGS (\Flagged)
T007 UID STORE 1,3,5 +FLAGS (\Deleted)
T008 UID STORE 1,3,5,7 +FLAGS (\Seen)
T009 UID STORE 1,3,5,7,9 +FLAGS (\Draft)
T010 UID STORE 1:* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
T011 UID STORE 1 -FLAGS (\Answered)
T012 UID STORE 1,3 -FLAGS (\Flagged)
T013 UID STORE 1,3,5 -FLAGS (\Deleted)
T014 UID STORE 1,3,5,7 -FLAGS (\Seen)
T015 UID STORE 1,3,5,7,9 -FLAGS (\Draft)
T016 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Recent)\r\n", res.next)
      assert_equal("T005 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Recent)\r\n", res.next)
      assert_equal("T006 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Recent)\r\n", res.next)
      assert_equal("T007 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Seen \\Recent)\r\n", res.next)
      assert_equal("T008 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Draft \\Recent)\r\n", res.next)
      assert_equal("T009 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T010 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Flagged \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T011 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Deleted \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T012 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Seen \\Draft \\Recent)\r\n", res.next)
      assert_equal("T013 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Draft \\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Draft \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Draft \\Recent)\r\n", res.next)
      assert_equal("T014 OK STORE completed\r\n", res.next)

      assert_equal("* 1 FETCH FLAGS (\\Recent)\r\n", res.next)
      assert_equal("* 2 FETCH FLAGS (\\Answered \\Recent)\r\n", res.next)
      assert_equal("* 3 FETCH FLAGS (\\Answered \\Flagged \\Recent)\r\n", res.next)
      assert_equal("* 4 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Recent)\r\n", res.next)
      assert_equal("* 5 FETCH FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Recent)\r\n", res.next)
      assert_equal("T015 OK STORE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T016 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end

    def test_command_loop_uid_store_silent
      msg_src = Enumerator.new{|y|
        s = 'a'
        loop do
          y << s
          s = s.succ
        end
      }

      10.times do
        @mail_store.add_msg(@inbox_id, msg_src.next)
      end
      @mail_store.each_msg_id(@inbox_id) do |msg_id|
        if (msg_id % 2 == 0) then
          @mail_store.set_msg_flag(@inbox_id, msg_id, 'deleted', true)
        end
      end

      @mail_store.expunge_mbox(@inbox_id)
      assert_equal([ 1, 3, 5, 7, 9 ], @mail_store.each_msg_id(@inbox_id).to_a)
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'answered'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'flagged'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'deleted'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'seen'))
      assert_equal(0, @mail_store.mbox_flags(@inbox_id, 'draft'))
      assert_equal(5, @mail_store.mbox_flags(@inbox_id, 'recent'))

      output = StringIO.new('', 'w')
      input = StringIO.new(<<-'EOF', 'r')
T001 UID STORE 1 +FLAGS.SILENT (\Answered)
T002 LOGIN foo open_sesame
T003 UID STORE 1 +FLAGS.SILENT (\Answered)
T004 SELECT INBOX
T005 UID STORE 1 +FLAGS.SILENT (\Answered)
T006 UID STORE 1,3 +FLAGS.SILENT (\Flagged)
T007 UID STORE 1,3,5 +FLAGS.SILENT (\Deleted)
T008 UID STORE 1,3,5,7 +FLAGS.SILENT (\Seen)
T009 UID STORE 1,3,5,7,9 +FLAGS.SILENT (\Draft)
T010 UID STORE 1:* FLAGS.SILENT (\Answered \Flagged \Deleted \Seen \Draft)
T011 UID STORE 1 -FLAGS.SILENT (\Answered)
T012 UID STORE 1,3 -FLAGS.SILENT (\Flagged)
T013 UID STORE 1,3,5 -FLAGS.SILENT (\Deleted)
T014 UID STORE 1,3,5,7 -FLAGS.SILENT (\Seen)
T015 UID STORE 1,3,5,7,9 -FLAGS.SILENT (\Draft)
T016 LOGOUT
      EOF

      RIMS::ProtocolDecoder.repl(@decoder, input, output, @logger)
      res = output.string.each_line

      assert_match(/^T001 NO /, res.next)

      assert_equal("T002 OK LOGIN completed\r\n", res.next)

      assert_match(/^T003 NO /, res.next)

      res.next while (res.peek =~ /^\* /)
      assert_equal("T004 OK [READ-WRITE] SELECT completed\r\n", res.next)

      assert_equal("T005 OK STORE completed\r\n", res.next)

      assert_equal("T006 OK STORE completed\r\n", res.next)

      assert_equal("T007 OK STORE completed\r\n", res.next)

      assert_equal("T008 OK STORE completed\r\n", res.next)

      assert_equal("T009 OK STORE completed\r\n", res.next)

      assert_equal("T010 OK STORE completed\r\n", res.next)

      assert_equal("T011 OK STORE completed\r\n", res.next)

      assert_equal("T012 OK STORE completed\r\n", res.next)

      assert_equal("T013 OK STORE completed\r\n", res.next)

      assert_equal("T014 OK STORE completed\r\n", res.next)

      assert_equal("T015 OK STORE completed\r\n", res.next)

      assert_match(/^\* BYE /, res.next)
      assert_equal("T016 OK LOGOUT completed\r\n", res.next)

      assert_raise(StopIteration) { res.next }
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
