;;; ox-opml.el --- Export Org files to OPML

;; Copyright (C) 2014 Eric Davis

;; Author: Eric Davis <eric@davising.com>
;; Keywords: opml, xml

;; This file is not yet part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

(require 'ox)

(org-export-define-backend 'opml
  '((headline . org-opml-headline)
    (section . (lambda (section contents info) contents))
    (plain-list . (lambda (section contents info) contents))
    (item . org-opml-item)
    (link . org-opml-link)
    (paragraph . org-opml-paragraph)
    (template . org-opml-template))
  :options-alist '((:opml-link "OPML_LINK" nil nil t)
		   (:opml-owner-id "OPML_OWNER_ID" nil opml-owner-id t))
  :menu-entry '(?o "Export to OPML"
		   (lambda (a s v b) (org-opml-export-to-opml a s v b)))
  :filters-alist '((:filter-final-output . org-opml-final-function)))

;;;###autoload
(defun org-opml-export-to-opml (&optional async subtreep visible-only body-only)
  (let ((file (org-export-output-file-name ".opml" subtreep)))
    (org-export-to-file 'opml file async subtreep visible-only body-only)))

(defun org-opml-headline (headline contents info)
  (let ((text (url-insert-entities-in-string (car (org-element-property :title headline))))
	(type (org-element-property :TYPE headline))
	(attributes (concat
		     (when (org-element-property :NAME headline)
		       (format " name=\"%s\" " (org-element-property :NAME headline)))
		     (when (org-element-property :CREATED headline)
		       (format " created=\"%s\" " (org-element-property :CREATED headline)))))
	(contents (if (string= contents "\n") "" (or contents ""))))
    (cond ((member type '("link" "include"))
	   (format "<outline text=\"%s\" type=\"%s\" url=\"%s\" %s>%s</outline>"
		   text type (org-element-property :URL headline) attributes contents))
	  ((string= type "rss")
	   (format "<outline text=\"%s\" type=\"rss\" xmlUrl=\"%s\" %s>%s</outline>"
		   text (org-element-property :XMLURL headline) attributes contents))
	  (type
	   (format "<outline text=\"%s\" type=\"%s\" %s>%s</outline>"
		   text type attributes contents))
	  (t
	   (format "<outline text=\"%s\" %s>%s</outline>"
		   text attributes contents)))))

(defun clean-text (str)
  "Remove problematic elements from STR.

1) Escape HTML entities (&, <, >, etc.)
2) Translate newlines into spaces
3) Remove any double spaces
4) Remove any trailing whitespace"
  (let* ((text (url-insert-entities-in-string str))
	 (text (replace-regexp-in-string "\n" " " text))
	 (text (replace-regexp-in-string "[ ][ ]+" " " text))
	 (text (replace-regexp-in-string " $" "" text)))
    text))

(defun org-opml-paragraph (paragraph contents info)
  (let* ((parent (org-element-type (org-export-get-parent paragraph)))
	 (text (clean-text contents)))
    ;; Only display paragraphs when not in a list item
    (unless (eq parent 'item)
      (format "<outline text=\"%s\"/>" text))))

(defun org-opml-item (item contents info)
  (let* ((p (org-element-map item 'paragraph 'identity nil t))
	 (text (clean-text (car (org-element-contents p)))))
    (concat
     (format "<outline text=\"%s\">" text)
     contents
     "</outline>")))

(defun org-opml-link (link contents info)
  (let ((url (org-element-property :raw-link link))
	(text (car (org-element-contents link))))
    (format "<a href=\"%s\">%s</a>" url text)))

(defun org-opml-add-header (key info &optional tag)
  (let ((tag (or tag (substring (symbol-name key) 1)))
	(value (plist-get info key)))
    (when value
      (format "<%s>%s</%s>" tag (if (listp value) (car value) value) tag))))

(defun org-opml-add-timestamp-headers ()
  (let* ((fmt "%a, %d %b %Y %H:%M:%S")
	 (attr (file-attributes (buffer-file-name)))
	 (modified (nth 5 attr))
	 (creation (current-time)))
    (concat
     (format "<dateModified>%s GMT</dateModified>" (format-time-string fmt modified t))
     (format "<dateCreated>%s GMT</dateCreated>" (format-time-string fmt creation t)))))

(defun org-opml-template (contents info)
  (concat
   "<?xml version=\"1.0\"?>"
   (format "<!-- OPML generated by %s on %s GMT -->"
	   org-export-creator-string
	   (format-time-string "%a, %d %b %Y %H:%M:%S" (current-time) t))
   "<opml version=\"2.0\">"
   "<head>"
   (org-opml-add-header :title info)
   (org-opml-add-header :description info)
   (org-opml-add-header :author info "ownerName")
   (org-opml-add-header :email info "ownerEmail")
   (org-opml-add-header :opml-owner-id info "ownerId")
   (org-opml-add-timestamp-headers)
   (org-opml-add-header :opml-link info "link")
   "<docs>http://dev.opml.org/spec2.html</docs>"
   "</head>"
   "<body>"
   contents
   "</body>"
   "</opml>"))

(defun org-opml-final-function (contents backend info)
  (with-temp-buffer
    (insert contents)
    (shell-command-on-region (point-min) (point-max) "xmllint --format -" nil t)
    (buffer-substring-no-properties (point-min) (point-max))))

(provide 'ox-opml)
