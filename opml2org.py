#!/usr/bin/env python

"""
opml2org.py -- convert OPML to Org mode
"""

import sys
import xml.etree.ElementTree as ET

def process_body(element, headline_depth=1, list_depth=0):
    for outline in element:
        attrib = outline.attrib.copy()
        assert 'text' in attrib, 'missing text attribute'
        text = attrib.pop('text')
        if 'structure' in attrib:
            structure = attrib.pop('structure')
        else:
            if attrib:
                structure = 'headline'
            elif len(outline):
                structure = 'list'
            else:
                structure = 'paragraph'

        if structure == 'headline':
            yield '%s %s' % ('*' * headline_depth, text)
            if attrib:
                yield ':PROPERTIES:'
                for k, v in attrib.iteritems():
                    yield ':%s: %s' % (k, v)
                yield ':END:\n'
            if len(outline):
                for child in process_body(outline, headline_depth + 1):
                    yield child
        elif structure == 'list':
            yield '%s- %s' % (' ' * list_depth, text)
            if len(outline):
                for child in process_body(outline, headline_depth, list_depth + 2):
                    yield child
        elif structure == 'paragraph':
            yield '%s\n' % text

def extract_header(head, tag, export_tag=None):
    if head.find(tag) is not None and head.find(tag).text:
        return '#+%s: %s' % (export_tag or tag.upper(), head.find(tag).text)

if __name__ == '__main__':
    head, body = ET.fromstring(sys.stdin.read())
    org_head = [
        extract_header(head, 'title'),
        extract_header(head, 'description'),
    ]
    org_body = process_body(body)

    sys.stdout.write((
        '\n'.join(filter(bool, org_head)) +
        '\n\n' +
        '\n'.join(org_body) +
        '\n'
    ).encode('utf-8', 'replace'))
