#!/usr/bin/python

import string,cgi,time
from os import curdir, sep

from pology.file.catalog import Catalog
from pology.misc.msgreport import report_msg_content

cat = Catalog("/home/sasha/messages/kdebase/dolphin.po")

class NoneType:
    def len():
        return 0

def msg_to_s(msg):
    return str({
        'manual_comment': msg.manual_comment,
        'auto_comment': msg.auto_comment,
        'source': msg.source,
        'flag': msg.flag,
        'obsolete': msg.obsolete,
        'msgctxt_previous': msg.msgctxt_previous,
        'msgid_previous': msg.msgid_previous,
        'msgid_plural_previous': msg.msgid_plural_previous,
        'msgctxt': msg.msgctxt,
        'msgid': msg.msgid,
        'msgid_plural': msg.msgid_plural,
        'msgstr': msg.msgstr,
        'refline': msg.refline,
        'refentry': msg.refentry,
        })

def main():
    print map(msg_to_s, cat)

if __name__ == '__main__':
    main()

