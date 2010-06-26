#!/usr/bin/python
#Copyright Jon Berg , turtlemeat.com

import string,cgi,time
from os import curdir, sep
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
#import pri

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

class MyHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        try:
            if self.path.endswith("/cat"):
                self.send_response(200)
                self.end_headers()
                self.wfile.write("<html>")
		self.wfile.write(map(msg_to_s, cat))
                self.wfile.write("</html>")
            if self.path.endswith(".html"):
                f = open(curdir + sep + self.path) #self.path has /test.html
#note that this potentially makes every file on your computer readable by the internet

                self.send_response(200)
                self.send_header('Content-type',	'text/html')
                self.end_headers()
                self.wfile.write(f.read())
                f.close()
                return
            if self.path.endswith(".esp"):   #our dynamic content
                self.send_response(200)
                self.send_header('Content-type',	'text/html')
                self.end_headers()
                self.wfile.write("hey, today is the" + str(time.localtime()[7]))
                self.wfile.write(" day in the year " + str(time.localtime()[0]))
                return
                
            return
                
        except IOError:
            self.send_error(404,'File Not Found: %s' % self.path)
     

    def do_POST(self):
        global rootnode
        try:
            ctype, pdict = cgi.parse_header(self.headers.getheader('content-type'))
            if ctype == 'multipart/form-data':
                query=cgi.parse_multipart(self.rfile, pdict)
            self.send_response(301)
            
            self.end_headers()
            upfilecontent = query.get('upfile')
            print "filecontent", upfilecontent[0]
            self.wfile.write("<HTML>POST OK.<BR><BR>");
            self.wfile.write(upfilecontent[0]);
            
        except :
            pass

def main():
    try:
        server = HTTPServer(('localhost', 40100), MyHandler)
        print 'started httpserver...'
        server.serve_forever()
    except KeyboardInterrupt:
        print '^C received, shutting down server'
        server.socket.close()

if __name__ == '__main__':
    main()

