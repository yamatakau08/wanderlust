;;; elmo-msgdb.el --- Message Database for ELMO.

;; Copyright (C) 1998,1999,2000 Yuuichi Teranishi <teranisi@gohome.org>
;; Copyright (C) 2000           Masahiro MURATA <muse@ba2.so-net.ne.jp>

;; Author: Yuuichi Teranishi <teranisi@gohome.org>
;;	Masahiro MURATA <muse@ba2.so-net.ne.jp>
;; Keywords: mail, net news

;; This file is part of ELMO (Elisp Library for Message Orchestration).

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.
;;

;;; Commentary:
;;

;;; Code:
;;

(eval-when-compile (require 'cl))
(require 'elmo-vars)
(require 'elmo-util)
(require 'emu)
(require 'std11)
(require 'mime)

(defconst elmo-msgdb-new-mark "N"
  "Mark for new message.")

(defconst elmo-msgdb-unread-uncached-mark "U"
  "Mark for unread and uncached message.")

(defconst elmo-msgdb-unread-cached-mark "!"
  "Mark for unread but already cached message.")

(defconst elmo-msgdb-read-uncached-mark "u"
  "Mark for read but uncached message.")

(defconst elmo-msgdb-answered-cached-mark "&"
  "Mark for answered and cached message.")

(defconst elmo-msgdb-answered-uncached-mark "A"
  "Mark for answered but cached message.")

(defconst elmo-msgdb-important-mark "$"
  "Mark for important message.")

;;; MSGDB interface.
;;
;; MSGDB elmo-load-msgdb PATH
;; MARK elmo-msgdb-get-mark MSGDB NUMBER 

;; CACHED elmo-msgdb-get-cached MSGDB NUMBER
;; VOID elmo-msgdb-set-cached MSGDB NUMBER CACHED USE-CACHE
;; VOID elmo-msgdb-set-flag MSGDB FOLDER NUMBER FLAG
;; VOID elmo-msgdb-unset-flag MSGDB FOLDER NUMBER FLAG

;; LIST-OF-NUMBERS elmo-msgdb-count-marks MSGDB
;; NUMBER elmo-msgdb-get-number MSGDB MESSAGE-ID
;; FIELD-VALUE elmo-msgdb-get-field MSGDB NUMBER FIELD
;; MSGDB elmo-msgdb-append MSGDB MSGDB-APPEND
;; MSGDB elmo-msgdb-clear MSGDB
;; elmo-msgdb-delete-messages MSGDB NUMBERS
;; elmo-msgdb-sort-by-date MSGDB

;;;
;; LIST-OF-NUMBERS elmo-msgdb-list-messages MSGDB

;; elmo-flag-table-load
;; elmo-flag-table-set
;; elmo-flag-table-get
;; elmo-flag-table-save

;; elmo-msgdb-append-entity MSGDB ENTITY MARK-OR-FLAGS

;; ENTITY elmo-msgdb-make-entity ARGS
;; VALUE elmo-msgdb-entity-field ENTITY
;; 

;; OVERVIEW elmo-msgdb-get-overview MSGDB
;; NUMBER-ALIST elmo-msgdb-get-number-alist MSGDB
;; MARK-ALIST elmo-msgdb-get-mark-alist MSGDB
;; elmo-msgdb-change-mark MSGDB BEFORE AFTER

;; (for internal use?)
;; LIST-OF-MARKS elmo-msgdb-unread-marks 
;; LIST-OF-MARKS elmo-msgdb-answered-marks 
;; LIST-OF-MARKS elmo-msgdb-uncached-marks 
;; elmo-msgdb-overview-save DIR OBJ

;; elmo-msgdb-message-entity MSGDB KEY

;;; Abolish
;; elmo-msgdb-overview-entity-get-references ENTITY
;; elmo-msgdb-overview-entity-set-references ENTITY
;; elmo-msgdb-get-parent-entity ENTITY MSGDB
;; elmo-msgdb-overview-enitty-get-number ENTITY
;; elmo-msgdb-overview-enitty-get-from-no-decode ENTITY
;; elmo-msgdb-overview-enitty-get-from ENTITY
;; elmo-msgdb-overview-enitty-get-subject-no-decode ENTITY
;; elmo-msgdb-overview-enitty-get-subject ENTITY
;; elmo-msgdb-overview-enitty-get-date ENTITY
;; elmo-msgdb-overview-enitty-get-to ENTITY
;; elmo-msgdb-overview-enitty-get-cc ENTITY
;; elmo-msgdb-overview-enitty-get-size ENTITY
;; elmo-msgdb-overview-enitty-get-id ENTITY
;; elmo-msgdb-overview-enitty-get-extra-field ENTITY
;; elmo-msgdb-overview-enitty-get-extra ENTITY
;; elmo-msgdb-overview-get-entity ID MSGDB

;; elmo-msgdb-killed-list-load DIR
;; elmo-msgdb-killed-list-save DIR
;; elmo-msgdb-append-to-killed-list FOLDER MSG
;; elmo-msgdb-killed-list-length KILLED-LIST
;; elmo-msgdb-max-of-killed KILLED-LIST
;; elmo-msgdb-killed-message-p KILLED-LIST MSG
;; elmo-living-messages MESSAGES KILLED-LIST
;; elmo-msgdb-finfo-load
;; elmo-msgdb-finfo-save
;; elmo-msgdb-flist-load
;; elmo-msgdb-flist-save

;; elmo-crosspost-alist-load
;; elmo-crosspost-alist-save

;; elmo-msgdb-create-overview-from-buffer NUMBER SIZE TIME
;; elmo-msgdb-copy-overview-entity ENTITY
;; elmo-msgdb-create-overview-entity-from-file NUMBER FILE
;; elmo-msgdb-clear-index

;; elmo-folder-get-info
;; elmo-folder-get-info-max
;; elmo-folder-get-info-length
;; elmo-folder-get-info-unread

;; elmo-msgdb-list-flagged MSGDB FLAG
;; (MACRO) elmo-msgdb-do-each-entity 

;;; MSGDB interface
;;
(eval-and-compile
  (luna-define-class elmo-msgdb () (location		; location for save.
				    message-modified	; message is modified.
				    flag-modified	; flag is modified.
				    ))
  (luna-define-internal-accessors 'elmo-msgdb))

(luna-define-generic elmo-msgdb-load (msgdb)
  "Load the MSGDB.")

(luna-define-generic elmo-msgdb-save (msgdb)
  "Save the MSGDB.")

(luna-define-generic elmo-msgdb-location (msgdb)
  "Return the location of MSGDB.")

(luna-define-generic elmo-msgdb-message-modified-p (msgdb)
  "Return non-nil if message is modified.")

(luna-define-generic elmo-msgdb-flag-modified-p (msgdb)
  "Return non-nil if flag is modified.")

(luna-define-generic elmo-msgdb-append (msgdb msgdb-append)
  "Append the MSGDB-APPEND to the MSGDB.
Return a list of messages which have duplicated message-id.")

(luna-define-generic elmo-msgdb-clear (msgdb)
  "Clear the MSGDB structure.")

(luna-define-generic elmo-msgdb-flags (msgdb number)
  "Return a list of flag which corresponds to the message with NUMBER.")

(luna-define-generic elmo-msgdb-set-flag (msgdb number flag)
  "Set message flag.
MSGDB is the ELMO msgdb.
NUMBER is a message number to set flag.
FLAG is a symbol which is one of the following:
`new'       ... Message which is new.
`read'      ... Message which is already read.
`important' ... Message which is marked as important.
`answered'  ... Message which is marked as answered.
`cached'    ... Message which is cached.")

(luna-define-generic elmo-msgdb-unset-flag (msgdb number flag)
  "Unset message flag.
MSGDB is the ELMO msgdb.
NUMBER is a message number to set flag.
FLAG is a symbol which is one of the following:
`new'       ... Message which is new.
`read'      ... Message which is already read.
`important' ... Message which is marked as important.
`answered'  ... Message which is marked as answered.
`cached'    ... Message which is cached.")

(luna-define-generic elmo-msgdb-list-messages (msgdb)
  "Return a list of message numbers in the MSGDB.")

(luna-define-generic elmo-msgdb-list-flagged (msgdb flag)
  "Return a list of message numbers which is set FLAG in the MSGDB.")

;;; (luna-define-generic elmo-msgdb-search (msgdb condition &optional numbers)
;;;   "Search and return list of message numbers.
;;; MSGDB is the ELMO msgdb structure.
;;; CONDITION is a condition structure for searching.
;;; If optional argument NUMBERS is specified and is a list of message numbers,
;;; messages are searched from the list.")

(luna-define-generic elmo-msgdb-append-entity (msgdb entity &optional flags)
  "Append a ENTITY with FLAGS into the MSGDB.
Return non-nil if message-id of entity is duplicated.")

(luna-define-generic elmo-msgdb-delete-messages (msgdb numbers)
  "Delete messages which are contained NUMBERS from MSGDB.")

(luna-define-generic elmo-msgdb-sort-entities (msgdb predicate &optional app-data)
  "Sort entities of MSGDB, comparing with PREDICATE.
PREDICATE is called with two entities and APP-DATA.
Should return non-nil if the first entity is \"less\" than the second.")

(luna-define-generic elmo-msgdb-message-entity (msgdb key)
  "Return the message-entity structure which matches to the KEY.
KEY is a number or a string.
A number is for message number in the MSGDB.
A string is for message-id of the message.")

;;; generic implement
;;
(luna-define-method elmo-msgdb-location ((msgdb elmo-msgdb))
  (elmo-msgdb-location-internal msgdb))

(luna-define-method elmo-msgdb-message-modified-p ((msgdb elmo-msgdb))
  (elmo-msgdb-message-modified-internal msgdb))

(luna-define-method elmo-msgdb-flag-modified-p ((msgdb elmo-msgdb))
  (elmo-msgdb-flag-modified-internal msgdb))

(luna-define-method elmo-msgdb-clear ((msgdb elmo-msgdb))
  (elmo-msgdb-set-message-modified-internal msgdb nil)
  (elmo-msgdb-set-flag-modified-internal msgdb nil))

(luna-define-method elmo-msgdb-append ((msgdb elmo-msgdb) msgdb-append)
  (let (duplicates)
    (dolist (number (elmo-msgdb-list-messages msgdb-append))
      (when (elmo-msgdb-append-entity
	     msgdb
	     (elmo-msgdb-message-entity msgdb-append number)
	     (elmo-msgdb-flags msgdb-append number))
	(setq duplicates (cons number duplicates))))
    duplicates))
  

;;; legacy implement
;;
(eval-and-compile
  (luna-define-class elmo-msgdb-legacy (elmo-msgdb)
		     (overview number-alist mark-alist index))
  (luna-define-internal-accessors 'elmo-msgdb-legacy))

;; for internal use only
(defsubst elmo-msgdb-get-overview (msgdb)
  (elmo-msgdb-legacy-overview-internal msgdb))

(defsubst elmo-msgdb-get-number-alist (msgdb)
  (elmo-msgdb-legacy-number-alist-internal msgdb))

(defsubst elmo-msgdb-get-mark-alist (msgdb)
  (elmo-msgdb-legacy-mark-alist-internal msgdb))

(defsubst elmo-msgdb-get-index (msgdb)
  (elmo-msgdb-legacy-index-internal msgdb))

(defsubst elmo-msgdb-get-entity-hashtb (msgdb)
  (car (elmo-msgdb-legacy-index-internal msgdb)))

(defsubst elmo-msgdb-get-mark-hashtb (msgdb)
  (cdr (elmo-msgdb-legacy-index-internal msgdb)))

(defsubst elmo-msgdb-get-path (msgdb)
  (elmo-msgdb-location msgdb))

(defsubst elmo-msgdb-set-overview (msgdb overview)
  (elmo-msgdb-legacy-set-overview-internal msgdb overview))

(defsubst elmo-msgdb-set-number-alist (msgdb number-alist)
  (elmo-msgdb-legacy-set-number-alist-internal msgdb number-alist))

(defsubst elmo-msgdb-set-mark-alist (msgdb mark-alist)
  (elmo-msgdb-legacy-set-mark-alist-internal msgdb mark-alist))

(defsubst elmo-msgdb-set-index (msgdb index)
  (elmo-msgdb-legacy-set-index-internal msgdb index))

(defsubst elmo-msgdb-set-path (msgdb path)
  (elmo-msgdb-set-location-internal msgdb path))


;;
(luna-define-method elmo-msgdb-load ((msgdb elmo-msgdb-legacy))
  (let ((inhibit-quit t)
	(path (elmo-msgdb-location msgdb)))
    (when (file-exists-p (expand-file-name elmo-msgdb-mark-filename path))
      (elmo-msgdb-legacy-set-overview-internal
       msgdb
       (elmo-msgdb-overview-load path))
      (elmo-msgdb-legacy-set-number-alist-internal
       msgdb
       (elmo-msgdb-number-load path))
      (elmo-msgdb-legacy-set-mark-alist-internal
       msgdb
       (elmo-msgdb-mark-load path))
      (elmo-msgdb-make-index msgdb)
      t)))

(luna-define-method elmo-msgdb-save ((msgdb elmo-msgdb-legacy))
  (let ((path (elmo-msgdb-location msgdb)))
    (when (elmo-msgdb-message-modified-p msgdb)
      (elmo-msgdb-overview-save
       path
       (elmo-msgdb-legacy-overview-internal msgdb))
      (elmo-msgdb-number-save
       path
       (elmo-msgdb-legacy-number-alist-internal msgdb))
      (elmo-msgdb-set-message-modified-internal msgdb nil))
    (when (elmo-msgdb-flag-modified-p msgdb)
      (elmo-msgdb-mark-save
       path
       (elmo-msgdb-legacy-mark-alist-internal msgdb))
      (elmo-msgdb-set-flag-modified-internal msgdb nil))))

(defun elmo-load-msgdb (location)
  "Load the MSGDB from PATH."
  (let ((msgdb (elmo-make-msgdb location)))
    (elmo-msgdb-load msgdb)
    msgdb))

(defun elmo-make-msgdb (&optional location)
  "Make a MSGDB."
  (luna-make-entity 'elmo-msgdb-legacy :location location))

(luna-define-method elmo-msgdb-list-messages ((msgdb elmo-msgdb-legacy))
  (mapcar 'elmo-msgdb-overview-entity-get-number
	  (elmo-msgdb-get-overview msgdb)))

(defsubst elmo-msgdb-mark-to-flags (mark)
  (append
   (and (string= mark elmo-msgdb-new-mark)
	'(new))
   (and (string= mark elmo-msgdb-important-mark)
	'(important))
   (and (member mark (elmo-msgdb-unread-marks))
	'(unread))
   (and (member mark (elmo-msgdb-answered-marks))
	'(answered))
   (and (not (member mark (elmo-msgdb-uncached-marks)))
	'(cached))))

(defsubst elmo-msgdb-flags-to-mark (flags)
  (cond ((memq 'new flags)
	 elmo-msgdb-new-mark)
	((memq 'important flags)
	 elmo-msgdb-important-mark)
	((memq 'answered flags)
	 (if (memq 'cached flags)
	     elmo-msgdb-answered-cached-mark
	   elmo-msgdb-answered-uncached-mark))
	((memq 'unread flags)
	 (if (memq 'cached flags)
	     elmo-msgdb-unread-cached-mark
	   elmo-msgdb-unread-uncached-mark))
	(t
	 (if (memq 'cached flags)
	     nil
	   elmo-msgdb-read-uncached-mark))))

(defsubst elmo-msgdb-get-mark (msgdb number)
  "Get mark string from MSGDB which corresponds to the message with NUMBER."
  (cadr (elmo-get-hash-val (format "#%d" number)
			   (elmo-msgdb-get-mark-hashtb msgdb))))

(defsubst elmo-msgdb-set-mark (msgdb number mark)
  "Set MARK of the message with NUMBER in the MSGDB.
if MARK is nil, mark is removed."
  (let ((elem (elmo-get-hash-val (format "#%d" number)
				 (elmo-msgdb-get-mark-hashtb msgdb))))
    (if elem
	(if mark
	    ;; Set mark of the elem
	    (setcar (cdr elem) mark)
	  ;; Delete elem from mark-alist
	  (elmo-msgdb-set-mark-alist
	   msgdb
	   (delq elem (elmo-msgdb-get-mark-alist msgdb)))
	  (elmo-clear-hash-val (format "#%d" number)
			       (elmo-msgdb-get-mark-hashtb msgdb)))
      (when mark
	;; Append new element.
	(elmo-msgdb-set-mark-alist
	 msgdb
	 (nconc
	  (elmo-msgdb-get-mark-alist msgdb)
	  (list (setq elem (list number mark)))))
	(elmo-set-hash-val (format "#%d" number) elem
			   (elmo-msgdb-get-mark-hashtb msgdb))))
    (elmo-msgdb-set-flag-modified-internal msgdb t)
    ;; return value.
    t))

(luna-define-method elmo-msgdb-flags ((msgdb elmo-msgdb-legacy) number)
  (elmo-msgdb-mark-to-flags (elmo-msgdb-get-mark msgdb number)))

(luna-define-method elmo-msgdb-set-flag ((msgdb elmo-msgdb-legacy)
					 number flag)
  (case flag
    (read
     (elmo-msgdb-unset-flag msgdb number 'unread))
    (uncached
     (elmo-msgdb-unset-flag msgdb number 'cached))
    (t
     (let* ((cur-mark (elmo-msgdb-get-mark msgdb number))
	    (flags (elmo-msgdb-mark-to-flags cur-mark))
	    new-mark)
       (and (memq 'new flags)
	    (setq flags (delq 'new flags)))
       (or (memq flag flags)
	   (setq flags (cons flag flags)))
       (when (and (eq flag 'unread)
		  (memq 'answered flags))
	 (setq flags (delq 'answered flags)))
       (setq new-mark (elmo-msgdb-flags-to-mark flags))
       (unless (string= new-mark cur-mark)
	 (elmo-msgdb-set-mark msgdb number new-mark))))))

(luna-define-method elmo-msgdb-unset-flag ((msgdb elmo-msgdb-legacy)
					   number flag)
  (case flag
    (read
     (elmo-msgdb-set-flag msgdb number 'unread))
    (uncached
     (elmo-msgdb-set-flag msgdb number 'cached))
    (t
     (let* ((cur-mark (elmo-msgdb-get-mark msgdb number))
	    (flags (elmo-msgdb-mark-to-flags cur-mark))
	    new-mark)
       (and (memq 'new flags)
	    (setq flags (delq 'new flags)))
       (and (memq flag flags)
	    (setq flags (delq flag flags)))
       (when (and (eq flag 'unread)
		  (memq 'answered flags))
	 (setq flags (delq 'answered flags)))
       (setq new-mark (elmo-msgdb-flags-to-mark flags))
       (unless (string= new-mark cur-mark)
	 (elmo-msgdb-set-mark msgdb number new-mark))))))

(defvar elmo-msgdb-unread-marks-internal nil)
(defsubst elmo-msgdb-unread-marks ()
  "Return an unread mark list"
  (or elmo-msgdb-unread-marks-internal
      (setq elmo-msgdb-unread-marks-internal
	    (list elmo-msgdb-new-mark
		  elmo-msgdb-unread-uncached-mark
		  elmo-msgdb-unread-cached-mark))))

(defvar elmo-msgdb-answered-marks-internal nil)
(defsubst elmo-msgdb-answered-marks ()
  "Return an answered mark list"
  (or elmo-msgdb-answered-marks-internal
      (setq elmo-msgdb-answered-marks-internal
	    (list elmo-msgdb-answered-cached-mark
		  elmo-msgdb-answered-uncached-mark))))

(defvar elmo-msgdb-uncached-marks-internal nil)
(defsubst elmo-msgdb-uncached-marks ()
  (or elmo-msgdb-uncached-marks-internal
      (setq elmo-msgdb-uncached-marks-internal
	    (list elmo-msgdb-new-mark
		  elmo-msgdb-answered-uncached-mark
		  elmo-msgdb-unread-uncached-mark
		  elmo-msgdb-read-uncached-mark))))

(luna-define-method elmo-msgdb-append-entity ((msgdb elmo-msgdb-legacy)
					      entity &optional flags)
  (when entity
    (let ((number (elmo-msgdb-overview-entity-get-number entity))
	  (message-id (elmo-msgdb-overview-entity-get-id entity))
	  mark)
      (elmo-msgdb-set-overview
       msgdb
       (nconc (elmo-msgdb-get-overview msgdb)
	      (list entity)))
      (elmo-msgdb-set-number-alist
       msgdb
       (nconc (elmo-msgdb-get-number-alist msgdb)
	      (list (cons number message-id))))
      (elmo-msgdb-set-message-modified-internal msgdb t)
      (when (setq mark (elmo-msgdb-flags-to-mark flags))
	(elmo-msgdb-set-mark-alist
	 msgdb
	 (nconc (elmo-msgdb-get-mark-alist msgdb)
		(list (list number mark))))
	(elmo-msgdb-set-flag-modified-internal msgdb t))
      (elmo-msgdb-make-index
       msgdb
       (list entity)
       (list (list number mark))))))

(defsubst elmo-msgdb-get-number (msgdb message-id)
  "Get number of the message which corrensponds to MESSAGE-ID from MSGDB."
  (elmo-msgdb-overview-entity-get-number
   (elmo-msgdb-overview-get-entity message-id msgdb)))

(defsubst elmo-msgdb-get-field (msgdb number field)
  "Get FIELD value of the message with NUMBER from MSGDB."
  (case field
    (message-id (elmo-msgdb-overview-entity-get-id
		 (elmo-msgdb-overview-get-entity
		  number msgdb)))
    (subject (elmo-msgdb-overview-entity-get-subject
	      (elmo-msgdb-overview-get-entity
	       number msgdb)))
    (size (elmo-msgdb-overview-entity-get-size
	   (elmo-msgdb-overview-get-entity
	    number msgdb)))
    (date (elmo-msgdb-overview-entity-get-date
	   (elmo-msgdb-overview-get-entity
	    number msgdb)))
    (to (elmo-msgdb-overview-entity-get-to
	 (elmo-msgdb-overview-get-entity
	  number msgdb)))
    (cc (elmo-msgdb-overview-entity-get-cc
	 (elmo-msgdb-overview-get-entity
	  number msgdb)))))

(luna-define-method elmo-msgdb-append :around ((msgdb elmo-msgdb-legacy)
					       msgdb-append)
  (if (eq (luna-class-name msgdb-append)
	  'elmo-msgdb-legacy)
      (let (duplicates)
	(elmo-msgdb-set-overview
	 msgdb
	 (nconc (elmo-msgdb-get-overview msgdb)
		(elmo-msgdb-get-overview msgdb-append)))
	(elmo-msgdb-set-number-alist
	 msgdb
	 (nconc (elmo-msgdb-get-number-alist msgdb)
		(elmo-msgdb-get-number-alist msgdb-append)))
	(elmo-msgdb-set-mark-alist
	 msgdb
	 (nconc (elmo-msgdb-get-mark-alist msgdb)
		(elmo-msgdb-get-mark-alist msgdb-append)))
	(setq duplicates (elmo-msgdb-make-index
			  msgdb
			  (elmo-msgdb-get-overview msgdb-append)
			  (elmo-msgdb-get-mark-alist msgdb-append)))
	(elmo-msgdb-set-path
	 msgdb
	 (or (elmo-msgdb-get-path msgdb)
	     (elmo-msgdb-get-path msgdb-append)))
	(elmo-msgdb-set-message-modified-internal msgdb t)
	(elmo-msgdb-set-flag-modified-internal msgdb t)
	duplicates)
    (luna-call-next-method)))

(defun elmo-msgdb-merge (folder msgdb-merge)
  "Return a list of messages which have duplicated message-id."
  (let (msgdb duplicates)
    (setq msgdb (or (elmo-folder-msgdb-internal folder)
		    (elmo-make-msgdb (elmo-folder-msgdb-path folder))))
    (setq duplicates (elmo-msgdb-append msgdb msgdb-merge))
    (elmo-folder-set-msgdb-internal folder msgdb)
    duplicates))

(luna-define-method elmo-msgdb-clear :after ((msgdb elmo-msgdb-legacy))
  (elmo-msgdb-set-overview msgdb nil)
  (elmo-msgdb-set-number-alist msgdb nil)
  (elmo-msgdb-set-mark-alist msgdb nil)
  (elmo-msgdb-set-index msgdb nil))

(luna-define-method elmo-msgdb-delete-messages ((msgdb elmo-msgdb-legacy)
						numbers)
  (let* ((overview (elmo-msgdb-get-overview msgdb))
	 (number-alist (elmo-msgdb-get-number-alist msgdb))
	 (mark-alist (elmo-msgdb-get-mark-alist msgdb))
	 (index (elmo-msgdb-get-index msgdb))
	 ov-entity)
    ;; remove from current database.
    (dolist (number numbers)
      (setq overview
	    (delq
	     (setq ov-entity
		   (elmo-msgdb-overview-get-entity number msgdb))
	     overview))
      (setq number-alist (delq (assq number number-alist) number-alist))
      (setq mark-alist (delq (assq number mark-alist) mark-alist))
      ;;
      (when index (elmo-msgdb-clear-index msgdb ov-entity)))
    (elmo-msgdb-set-overview msgdb overview)
    (elmo-msgdb-set-number-alist msgdb number-alist)
    (elmo-msgdb-set-mark-alist msgdb mark-alist)
    (elmo-msgdb-set-index msgdb index)
    (elmo-msgdb-set-message-modified-internal msgdb t)
    (elmo-msgdb-set-flag-modified-internal msgdb t)
    t)) ;return value

(luna-define-method elmo-msgdb-sort-entities ((msgdb elmo-msgdb-legacy)
					      predicate &optional app-data)
  (message "Sorting...")
  (let ((overview (elmo-msgdb-get-overview msgdb)))
    (elmo-msgdb-set-overview
     msgdb
     (sort overview (lambda (a b) (funcall predicate a b app-data))))
    (message "Sorting...done")
    msgdb))

(defun elmo-msgdb-sort-by-date (msgdb)
  (elmo-msgdb-sort-entities
   msgdb
   (lambda (x y app-data)
     (condition-case nil
	 (string<
	  (timezone-make-date-sortable
	   (elmo-msgdb-overview-entity-get-date x))
	  (timezone-make-date-sortable
	   (elmo-msgdb-overview-entity-get-date y)))
       (error)))))

;;;
(defsubst elmo-msgdb-append-element (list element)
  (if list
;;;   (append list (list element))
      (nconc list (list element))
    ;; list is nil
    (list element)))

;;
;; number <-> Message-ID handling
;;
(defsubst elmo-msgdb-number-add (alist number id)
  (let ((ret-val alist))
    (setq ret-val
	  (elmo-msgdb-append-element ret-val (cons number id)))
    ret-val))

;;; flag table
;;
(defvar elmo-flag-table-filename "flag-table")
(defun elmo-flag-table-load (dir)
  "Load flag hashtable for MSGDB."
  (let ((table (elmo-make-hash))
	;; For backward compatibility
	(seen-file (expand-file-name elmo-msgdb-seen-filename dir))
	value)
    (when (file-exists-p seen-file)
      (dolist (msgid (elmo-object-load seen-file))
	(elmo-set-hash-val msgid '(read) table))
      (delete-file seen-file))
    (dolist (pair (elmo-object-load
		   (expand-file-name elmo-flag-table-filename dir)))
      (setq value (cdr pair))
      (elmo-set-hash-val (car pair)
			 (cond ((consp value)
				value)
			       ;; Following cases for backward compatibility.
			       (value
				(list value))
			       (t
				'(unread)))
			 table))
    table))

(defun elmo-flag-table-set (flag-table msg-id flags)
  (elmo-set-hash-val msg-id (or flags '(read)) flag-table))

(defun elmo-flag-table-get (flag-table msg-id)
  (let ((flags (elmo-get-hash-val msg-id flag-table)))
    (if flags
	(append
	 (and (elmo-msgdb-global-mark-get msg-id)
	      '(important))
	 (and (elmo-file-cache-exists-p msg-id)
	      '(cached))
	 (elmo-list-delete '(important cached read)
			   (copy-sequence flags)
			   #'delq))
      '(new unread))))

(defun elmo-flag-table-save (dir flag-table)
  (elmo-object-save
   (expand-file-name elmo-flag-table-filename dir)
   (if flag-table
       (let (list)
	 (mapatoms (lambda (atom)
		     (setq list (cons (cons (symbol-name atom)
					    (symbol-value atom))
				      list)))
		   flag-table)
	 list))))
;;;
;; persistent mark handling
;; (for each folder)

(defun elmo-msgdb-mark-append (alist id mark)
  "Append mark."
  (setq alist (elmo-msgdb-append-element alist
					 (list id mark))))

(defsubst elmo-msgdb-length (msgdb)
  (length (elmo-msgdb-get-overview msgdb)))

(defun elmo-msgdb-flag-table (msgdb &optional flag-table)
  ;; Make a table of msgid flag (read, answered)
  (let ((flag-table (or flag-table
			(elmo-make-hash (elmo-msgdb-length msgdb))))
	entity)
    (dolist (number (elmo-msgdb-list-messages msgdb))
      (setq entity (elmo-msgdb-message-entity msgdb number))
      (elmo-flag-table-set
       flag-table
       (elmo-msgdb-overview-entity-get-id entity)
       (elmo-msgdb-flags msgdb number)))
    flag-table))

;;
;; mime decode cache

(defvar elmo-msgdb-decoded-cache-hashtb nil)
(make-variable-buffer-local 'elmo-msgdb-decoded-cache-hashtb)

(defsubst elmo-msgdb-get-decoded-cache (string)
  (if elmo-use-decoded-cache
      (let ((hashtb (or elmo-msgdb-decoded-cache-hashtb
			(setq elmo-msgdb-decoded-cache-hashtb
			      (elmo-make-hash 2048))))
	    decoded)
	(or (elmo-get-hash-val string hashtb)
	    (progn
	      (elmo-set-hash-val
	       string
	       (setq decoded
		     (decode-mime-charset-string string elmo-mime-charset))
	       hashtb)
	      decoded)))
    (decode-mime-charset-string string elmo-mime-charset)))

;;
;; overview handling
;;
(defun elmo-multiple-field-body (name &optional boundary)
  (save-excursion
    (save-restriction
      (std11-narrow-to-header boundary)
      (goto-char (point-min))
      (let ((case-fold-search t)
	    (field-body nil))
	(while (re-search-forward (concat "^" name ":[ \t]*") nil t)
	  (setq field-body
		(nconc field-body
		       (list (buffer-substring-no-properties
			      (match-end 0) (std11-field-end))))))
	field-body))))

(defun elmo-multiple-fields-body-list (field-names &optional boundary)
  "Return list of each field-bodies of FIELD-NAMES of the message header
in current buffer. If BOUNDARY is not nil, it is used as message
header separator."
  (save-excursion
    (save-restriction
      (std11-narrow-to-header boundary)
      (let* ((case-fold-search t)
	     (s-rest field-names)
	     field-name field-body)
	(while (setq field-name (car s-rest))
	  (goto-char (point-min))
	  (while (re-search-forward (concat "^" field-name ":[ \t]*") nil t)
	    (setq field-body
		  (nconc field-body
			 (list (buffer-substring-no-properties
				(match-end 0) (std11-field-end))))))
	  (setq s-rest (cdr s-rest)))
	field-body))))

(defsubst elmo-msgdb-remove-field-string (string)
  (if (string-match (concat std11-field-head-regexp "[ \t]*") string)
      (substring string (match-end 0))
    string))

(defsubst elmo-msgdb-get-last-message-id (string)
  (if string
      (save-match-data
	(let (beg)
	  (elmo-set-work-buf
	   (insert string)
	   (goto-char (point-max))
	   (when (search-backward "<" nil t)
	     (setq beg (point))
	     (if (search-forward ">" nil t)
		 (elmo-replace-in-string
		  (buffer-substring beg (point)) "\n[ \t]*" ""))))))))

(defun elmo-msgdb-number-load (dir)
  (elmo-object-load
   (expand-file-name elmo-msgdb-number-filename dir)))

(defun elmo-msgdb-overview-load (dir)
  (elmo-object-load
   (expand-file-name elmo-msgdb-overview-filename dir)))

(defun elmo-msgdb-mark-load (dir)
  (elmo-object-load
   (expand-file-name elmo-msgdb-mark-filename dir)))

(defsubst elmo-msgdb-seen-load (dir)
  (elmo-object-load (expand-file-name
		     elmo-msgdb-seen-filename
		     dir)))

(defun elmo-msgdb-number-save (dir obj)
  (elmo-object-save
   (expand-file-name elmo-msgdb-number-filename dir)
   obj))

(defun elmo-msgdb-mark-save (dir obj)
  (elmo-object-save
   (expand-file-name elmo-msgdb-mark-filename dir)
   obj))

(defun elmo-msgdb-change-mark (msgdb before after)
  "Set the BEFORE marks to AFTER."
  (let ((mark-alist (elmo-msgdb-get-mark-alist msgdb))
	entity)
    (while mark-alist
      (setq entity (car mark-alist))
      (when (string= (cadr entity) before)
	(setcar (cdr entity) after))
      (setq mark-alist (cdr mark-alist)))))

(defsubst elmo-msgdb-out-of-date-messages (msgdb)
  (elmo-msgdb-change-mark msgdb
			  elmo-msgdb-new-mark
			  elmo-msgdb-unread-uncached-mark))

(defsubst elmo-msgdb-overview-save (dir overview)
  (elmo-object-save
   (expand-file-name elmo-msgdb-overview-filename dir)
   overview))

(defun elmo-msgdb-match-condition-primitive (condition mark entity numbers)
  (catch 'unresolved
    (let ((key (elmo-filter-key condition))
	  (case-fold-search t)
	  result)
      (cond
       ((string= key "last")
	(setq result (<= (length (memq
				  (elmo-msgdb-overview-entity-get-number
				   entity)
				  numbers))
			 (string-to-int (elmo-filter-value condition)))))
       ((string= key "first")
	(setq result (< (-
			 (length numbers)
			 (length (memq
				  (elmo-msgdb-overview-entity-get-number
				   entity)
				  numbers)))
			(string-to-int (elmo-filter-value condition)))))
       ((string= key "flag")
	(setq result
	      (cond
	       ((string= (elmo-filter-value condition) "any")
		(not (or (null mark)
			 (string= mark elmo-msgdb-read-uncached-mark))))
	       ((string= (elmo-filter-value condition) "digest")
		(not (or (null mark)
			 (string= mark elmo-msgdb-read-uncached-mark)
			 (string= mark elmo-msgdb-answered-cached-mark)
			 (string= mark elmo-msgdb-answered-uncached-mark))))
;;	  (member mark (append (elmo-msgdb-answered-marks)
;;			       (list elmo-msgdb-important-mark)
;;			       (elmo-msgdb-unread-marks))))
	       ((string= (elmo-filter-value condition) "unread")
		(member mark (elmo-msgdb-unread-marks)))
	       ((string= (elmo-filter-value condition) "important")
		(string= mark elmo-msgdb-important-mark))
	       ((string= (elmo-filter-value condition) "answered")
		(member mark (elmo-msgdb-answered-marks))))))
       ((string= key "from")
	(setq result (string-match
		      (elmo-filter-value condition)
		      (elmo-msgdb-overview-entity-get-from entity))))
       ((string= key "subject")
	(setq result (string-match
		      (elmo-filter-value condition)
		      (elmo-msgdb-overview-entity-get-subject entity))))
       ((string= key "to")
	(setq result (string-match
		      (elmo-filter-value condition)
		      (elmo-msgdb-overview-entity-get-to entity))))
       ((string= key "cc")
	(setq result (string-match
		      (elmo-filter-value condition)
		      (elmo-msgdb-overview-entity-get-cc entity))))
       ((or (string= key "since")
	    (string= key "before"))
	(let ((field-date (elmo-date-make-sortable-string
			   (timezone-fix-time
			    (elmo-msgdb-overview-entity-get-date entity)
			    (current-time-zone) nil)))
	      (specified-date
	       (elmo-date-make-sortable-string
		(elmo-date-get-datevec
		 (elmo-filter-value condition)))))
	  (setq result (if (string= key "since")
			   (or (string= specified-date field-date)
			       (string< specified-date field-date))
			 (string< field-date specified-date)))))
       ((member key elmo-msgdb-extra-fields)
	(let ((extval (elmo-msgdb-overview-entity-get-extra-field entity key)))
	  (when (stringp extval)
	    (setq result (string-match
			  (elmo-filter-value condition)
			  extval)))))
       (t
	(throw 'unresolved condition)))
      (if (eq (elmo-filter-type condition) 'unmatch)
	  (not result)
	result))))

(defun elmo-msgdb-match-condition-internal (condition mark entity numbers)
  (cond
   ((vectorp condition)
    (elmo-msgdb-match-condition-primitive condition mark entity numbers))
   ((eq (car condition) 'and)
    (let ((lhs (elmo-msgdb-match-condition-internal (nth 1 condition)
						    mark entity numbers)))
      (cond
       ((elmo-filter-condition-p lhs)
	(let ((rhs (elmo-msgdb-match-condition-internal
		    (nth 2 condition) mark entity numbers)))
	  (cond ((elmo-filter-condition-p rhs)
		 (list 'and lhs rhs))
		(rhs
		 lhs))))
       (lhs
	(elmo-msgdb-match-condition-internal (nth 2 condition)
					     mark entity numbers)))))
   ((eq (car condition) 'or)
    (let ((lhs (elmo-msgdb-match-condition-internal (nth 1 condition)
						    mark entity numbers)))
      (cond
       ((elmo-filter-condition-p lhs)
	(let ((rhs (elmo-msgdb-match-condition-internal (nth 2 condition)
							mark entity numbers)))
	  (cond ((elmo-filter-condition-p rhs)
		 (list 'or lhs rhs))
		(rhs
		 t)
		(t
		 lhs))))
       (lhs
	t)
       (t
	(elmo-msgdb-match-condition-internal (nth 2 condition)
					     mark entity numbers)))))))

(defun elmo-msgdb-match-condition (msgdb condition number numbers)
  "Check whether the condition of the message is satisfied or not.
MSGDB is the msgdb to search from.
CONDITION is the search condition.
NUMBER is the message number to check.
NUMBERS is the target message number list.
Return CONDITION itself if no entity exists in msgdb."
  (let ((entity (elmo-msgdb-overview-get-entity number msgdb)))
    (if entity
	(elmo-msgdb-match-condition-internal condition
					     (elmo-msgdb-get-mark msgdb number)
					     entity numbers)
      condition)))

(defsubst elmo-msgdb-overview-entity-get-references (entity)
  (and entity (aref (cdr entity) 1)))

(defsubst elmo-msgdb-overview-entity-set-references (entity references)
  (and entity (aset (cdr entity) 1 references))
  entity)

;; entity -> parent-entity
(defsubst elmo-msgdb-overview-get-parent-entity (entity database)
  (setq entity (elmo-msgdb-overview-entity-get-references entity))
  ;; entity is parent-id.
  (and entity (assoc entity database)))

(defsubst elmo-msgdb-get-parent-entity (entity msgdb)
  (setq entity (elmo-msgdb-overview-entity-get-references entity))
  ;; entity is parent-id.
  (and entity (elmo-msgdb-overview-get-entity entity msgdb)))

(defsubst elmo-msgdb-overview-entity-get-number (entity)
  (and entity (aref (cdr entity) 0)))

(defsubst elmo-msgdb-overview-entity-get-from-no-decode (entity)
  (and entity (aref (cdr entity) 2)))

(defsubst elmo-msgdb-overview-entity-get-from (entity)
  (and entity
       (aref (cdr entity) 2)
       (elmo-msgdb-get-decoded-cache (aref (cdr entity) 2))))

(defsubst elmo-msgdb-overview-entity-set-number (entity number)
  (and entity (aset (cdr entity) 0 number))
  entity)
;;;(setcar (cadr entity) number) entity)

(defsubst elmo-msgdb-overview-entity-set-from (entity from)
  (and entity (aset (cdr entity) 2 from))
  entity)

(defsubst elmo-msgdb-overview-entity-get-subject (entity)
  (and entity
       (aref (cdr entity) 3)
       (elmo-msgdb-get-decoded-cache (aref (cdr entity) 3))))

(defsubst elmo-msgdb-overview-entity-get-subject-no-decode (entity)
  (and entity (aref (cdr entity) 3)))

(defsubst elmo-msgdb-overview-entity-set-subject (entity subject)
  (and entity (aset (cdr entity) 3 subject))
  entity)

(defsubst elmo-msgdb-overview-entity-get-date (entity)
  (and entity (aref (cdr entity) 4)))

(defsubst elmo-msgdb-overview-entity-set-date (entity date)
  (and entity (aset (cdr entity) 4 date))
  entity)

(defsubst elmo-msgdb-overview-entity-get-to (entity)
  (and entity (aref (cdr entity) 5)))

(defsubst elmo-msgdb-overview-entity-get-cc (entity)
  (and entity (aref (cdr entity) 6)))

(defsubst elmo-msgdb-overview-entity-get-size (entity)
  (and entity (aref (cdr entity) 7)))

(defsubst elmo-msgdb-overview-entity-set-size (entity size)
  (and entity (aset (cdr entity) 7 size))
  entity)

(defsubst elmo-msgdb-overview-entity-get-id (entity)
  (and entity (car entity)))

(defsubst elmo-msgdb-overview-entity-get-extra-field (entity field-name)
  (let ((field-name (downcase field-name))
	(extra (and entity (aref (cdr entity) 8))))
    (and extra
	 (cdr (assoc field-name extra)))))

(defsubst elmo-msgdb-overview-entity-set-extra-field (entity field-name value)
  (let ((field-name (downcase field-name))
	(extras (and entity (aref (cdr entity) 8)))
	extra)
    (if (setq extra (assoc field-name extras))
	(setcdr extra value)
      (elmo-msgdb-overview-entity-set-extra
       entity
       (cons (cons field-name value) extras)))))

(defsubst elmo-msgdb-overview-entity-get-extra (entity)
  (and entity (aref (cdr entity) 8)))

(defsubst elmo-msgdb-overview-entity-set-extra (entity extra)
  (and entity (aset (cdr entity) 8 extra))
  entity)

;;; New APIs
(luna-define-method elmo-msgdb-message-entity ((msgdb elmo-msgdb-legacy) key)
  (elmo-get-hash-val 
   (cond ((stringp key) key)
	 ((numberp key) (format "#%d" key)))
   (elmo-msgdb-get-entity-hashtb msgdb)))

(defun elmo-msgdb-make-message-entity (&rest args)
  "Make an message entity."
  (cons (plist-get args :message-id)
	(vector (plist-get args :number)
		(plist-get args :references)
		(plist-get args :from)
		(plist-get args :subject)
		(plist-get args :date)
		(plist-get args :to)
		(plist-get args :cc)
		(plist-get args :size)
		(plist-get args :extra))))

(defsubst elmo-msgdb-message-entity-field (entity field &optional decode)
  (and entity
       (let ((field-value
	      (case field
		(to (aref (cdr entity) 5))
		(cc (aref (cdr entity) 6))
		(date (aref (cdr entity) 4))
		(subject (aref (cdr entity) 3))
		(from (aref (cdr entity) 2))
		(message-id (car entity))
		(references (aref (cdr entity) 1))
		(size (aref (cdr entity) 7))
		(t (cdr (assoc (symbol-name field) (aref (cdr entity) 8)))))))
	 (if (and decode (memq field '(from subject)))
	     (elmo-msgdb-get-decoded-cache field-value)
	   field-value))))

(defsubst elmo-msgdb-message-entity-set-field (entity field value)
  (and entity
       (case field
	 (to (aset (cdr entity) 5 value))
	 (cc (aset (cdr entity) 6 value))
	 (date (aset (cdr entity) 4 value))
	 (subject (aset (cdr entity) 3 value))
	 (from (aset (cdr entity) 2 value))
	 (message-id (setcar entity value))
	 (references (aset (cdr entity) 1 value))
	 (size (aset (cdr entity) 7 value))
	 (t
	  (let ((extras (and entity (aref (cdr entity) 8)))
		extra)
	    (if (setq extra (assoc field extras))
		(setcdr extra value)
	      (aset (cdr entity) 8 (cons (cons (symbol-name field)
					       value) extras))))))))

;;; 
(defun elmo-msgdb-overview-get-entity (id msgdb)
  (elmo-msgdb-message-entity msgdb id))

;;
;; deleted message handling
;;
(defun elmo-msgdb-killed-list-load (dir)
  (elmo-object-load
   (expand-file-name elmo-msgdb-killed-filename dir)
   nil t))

(defun elmo-msgdb-killed-list-save (dir killed-list)
  (elmo-object-save
   (expand-file-name elmo-msgdb-killed-filename dir)
   killed-list))

(defun elmo-msgdb-killed-message-p (killed-list msg)
  (elmo-number-set-member msg killed-list))

(defun elmo-msgdb-set-as-killed (killed-list msg)
  (elmo-number-set-append killed-list msg))

(defun elmo-msgdb-killed-list-length (killed-list)
  (let ((killed killed-list)
	(ret-val 0))
    (while (car killed)
      (if (consp (car killed))
	  (setq ret-val (+ ret-val 1 (- (cdar killed) (caar killed))))
	(setq ret-val (+ ret-val 1)))
      (setq killed (cdr killed)))
    ret-val))

(defun elmo-msgdb-max-of-killed (killed-list)
  (let ((klist killed-list)
	(max 0)
	k)
    (while (car klist)
      (if (< max
	     (setq k
		   (if (consp (car klist))
		       (cdar klist)
		     (car klist))))
	  (setq max k))
      (setq klist (cdr klist)))
    max))

(defun elmo-living-messages (messages killed-list)
  (if killed-list
      (delq nil
	    (mapcar (lambda (number)
		      (unless (elmo-number-set-member number killed-list)
			number))
		    messages))
    messages))

(defun elmo-msgdb-finfo-load ()
  (elmo-object-load (expand-file-name
		     elmo-msgdb-finfo-filename
		     elmo-msgdb-directory)
		    elmo-mime-charset t))

(defun elmo-msgdb-finfo-save (finfo)
  (elmo-object-save (expand-file-name
		     elmo-msgdb-finfo-filename
		     elmo-msgdb-directory)
		    finfo elmo-mime-charset))

(defun elmo-msgdb-flist-load (fname)
  (let ((flist-file (expand-file-name
		     elmo-msgdb-flist-filename
		     (expand-file-name
		      (elmo-safe-filename fname)
		      (expand-file-name "folder" elmo-msgdb-directory)))))
    (elmo-object-load flist-file elmo-mime-charset t)))

(defun elmo-msgdb-flist-save (fname flist)
  (let ((flist-file (expand-file-name
		     elmo-msgdb-flist-filename
		     (expand-file-name
		      (elmo-safe-filename fname)
		      (expand-file-name "folder" elmo-msgdb-directory)))))
    (elmo-object-save flist-file flist elmo-mime-charset)))

(defun elmo-crosspost-alist-load ()
  (elmo-object-load (expand-file-name
		     elmo-crosspost-alist-filename
		     elmo-msgdb-directory)
		    nil t))

(defun elmo-crosspost-alist-save (alist)
  (elmo-object-save (expand-file-name
		     elmo-crosspost-alist-filename
		     elmo-msgdb-directory)
		    alist))

(defun elmo-msgdb-get-message-id-from-buffer ()
  (let ((msgid (elmo-field-body "message-id")))
    (if msgid
	(if (string-match "<\\(.+\\)>$" msgid)
	    msgid
	  (concat "<" msgid ">")) ; Invaild message-id.
      ;; no message-id, so put dummy msgid.
      (concat "<" (timezone-make-date-sortable
		   (elmo-field-body "date"))
	      (nth 1 (eword-extract-address-components
		      (or (elmo-field-body "from") "nobody"))) ">"))))

(defsubst elmo-msgdb-create-overview-from-buffer (number &optional size time)
  "Create overview entity from current buffer.
Header region is supposed to be narrowed."
  (save-excursion
    (let ((extras elmo-msgdb-extra-fields)
	  (default-mime-charset default-mime-charset)
	  message-id references from subject to cc date
	  extra field-body charset)
      (elmo-set-buffer-multibyte default-enable-multibyte-characters)
      (setq message-id (elmo-msgdb-get-message-id-from-buffer))
      (and (setq charset (cdr (assoc "charset" (mime-read-Content-Type))))
	   (setq charset (intern-soft charset))
	   (setq default-mime-charset charset))
      (setq references
	    (or (elmo-msgdb-get-last-message-id
		 (elmo-field-body "in-reply-to"))
		(elmo-msgdb-get-last-message-id
		 (elmo-field-body "references"))))
      (setq from (elmo-replace-in-string
		  (elmo-mime-string (or (elmo-field-body "from")
					elmo-no-from))
		  "\t" " ")
	    subject (elmo-replace-in-string
		     (elmo-mime-string (or (elmo-field-body "subject")
					   elmo-no-subject))
		     "\t" " "))
      (setq date (or (elmo-field-body "date") time))
      (setq to   (mapconcat 'identity (elmo-multiple-field-body "to") ","))
      (setq cc   (mapconcat 'identity (elmo-multiple-field-body "cc") ","))
      (or size
	  (if (setq size (elmo-field-body "content-length"))
	      (setq size (string-to-int size))
	    (setq size 0)));; No mean...
      (while extras
	(if (setq field-body (elmo-field-body (car extras)))
	    (setq extra (cons (cons (downcase (car extras))
				    field-body) extra)))
	(setq extras (cdr extras)))
      (cons message-id (vector number references
			       from subject date to cc
			       size extra))
      )))

(defun elmo-msgdb-copy-overview-entity (entity)
  (cons (car entity)
	(copy-sequence (cdr entity))))

(defsubst elmo-msgdb-insert-file-header (file)
  "Insert the header of the article."
  (let ((beg 0)
	insert-file-contents-pre-hook   ; To avoid autoconv-xmas...
	insert-file-contents-post-hook
	format-alist)
    (when (file-exists-p file)
      ;; Read until header separator is found.
      (while (and (eq elmo-msgdb-file-header-chop-length
		      (nth 1
			   (insert-file-contents-as-binary
			    file nil beg
			    (incf beg elmo-msgdb-file-header-chop-length))))
		  (prog1 (not (search-forward "\n\n" nil t))
		    (goto-char (point-max))))))))

(defsubst elmo-msgdb-create-overview-entity-from-file (number file)
  (let (insert-file-contents-pre-hook   ; To avoid autoconv-xmas...
	insert-file-contents-post-hook header-end
	(attrib (file-attributes file))
	ret-val size mtime)
    (with-temp-buffer
      (if (not (file-exists-p file))
	  ()
	(setq size (nth 7 attrib))
	(setq mtime (timezone-make-date-arpa-standard
		     (current-time-string (nth 5 attrib)) (current-time-zone)))
	;; insert header from file.
	(catch 'done
	  (condition-case nil
	      (elmo-msgdb-insert-file-header file)
	    (error (throw 'done nil)))
	  (goto-char (point-min))
	  (setq header-end
		(if (re-search-forward "\\(^--.*$\\)\\|\\(\n\n\\)" nil t)
		    (point)
		  (point-max)))
	  (narrow-to-region (point-min) header-end)
	  (elmo-msgdb-create-overview-from-buffer number size mtime))))))

(defun elmo-msgdb-clear-index (msgdb entity)
  (let ((ehash (elmo-msgdb-get-entity-hashtb msgdb))
	(mhash (elmo-msgdb-get-mark-hashtb msgdb))
	number)
    (when (and entity ehash)
      (and (setq number (elmo-msgdb-overview-entity-get-number entity))
	   (elmo-clear-hash-val (format "#%d" number) ehash))
      (and (car entity) ;; message-id
	   (elmo-clear-hash-val (car entity) ehash)))
    (when (and entity mhash)
      (and (setq number (elmo-msgdb-overview-entity-get-number entity))
	   (elmo-clear-hash-val (format "#%d" number) mhash)))))

(defun elmo-msgdb-make-index (msgdb &optional overview mark-alist)
  "Append OVERVIEW and MARK-ALIST to the index of MSGDB.
If OVERVIEW and MARK-ALIST are nil, make index for current MSGDB.
Return a list of message numbers which have duplicated message-ids."
  (when msgdb
    (let* ((overview (or overview (elmo-msgdb-get-overview msgdb)))
	   (mark-alist (or mark-alist (elmo-msgdb-get-mark-alist msgdb)))
	   (index (elmo-msgdb-get-index msgdb))
	   (ehash (or (car index) ;; append
		      (elmo-make-hash (length overview))))
	   (mhash (or (cdr index) ;; append
		      (elmo-make-hash (length overview))))
	   duplicates)
      (while overview
	;; key is message-id
	(if (elmo-get-hash-val (caar overview) ehash) ; duplicated.
	    (setq duplicates (cons
			      (elmo-msgdb-overview-entity-get-number
			       (car overview))
			      duplicates)))
	(if (caar overview)
	    (elmo-set-hash-val (caar overview) (car overview) ehash))
	;; key is number
	(elmo-set-hash-val
	 (format "#%d"
		 (elmo-msgdb-overview-entity-get-number (car overview)))
	 (car overview) ehash)
	(setq overview (cdr overview)))
      (while mark-alist
	;; key is number
	(elmo-set-hash-val
	 (format "#%d" (car (car mark-alist)))
	 (car mark-alist) mhash)
	(setq mark-alist (cdr mark-alist)))
      (setq index (or index (cons ehash mhash)))
      (elmo-msgdb-set-index msgdb index)
      duplicates)))

(defsubst elmo-folder-get-info (folder &optional hashtb)
  (elmo-get-hash-val folder
		     (or hashtb elmo-folder-info-hashtb)))

(defun elmo-folder-get-info-max (folder)
  "Get folder info from cache."
  (nth 3 (elmo-folder-get-info folder)))

(defun elmo-folder-get-info-length (folder)
  (nth 2 (elmo-folder-get-info folder)))

(defun elmo-folder-get-info-unread (folder)
  (nth 1 (elmo-folder-get-info folder)))

(defsubst elmo-msgdb-location-load (dir)
  (elmo-object-load
   (expand-file-name
    elmo-msgdb-location-filename
    dir)))

(defsubst elmo-msgdb-location-add (alist number location)
  (let ((ret-val alist))
    (setq ret-val
	  (elmo-msgdb-append-element ret-val (cons number location)))
    ret-val))

(defsubst elmo-msgdb-location-save (dir alist)
  (elmo-object-save
   (expand-file-name
    elmo-msgdb-location-filename
    dir) alist))

(luna-define-method elmo-msgdb-list-flagged ((msgdb elmo-msgdb-legacy) flag)
  (let ((case-fold-search nil)
	mark-regexp matched)
    (case flag
      (new
       (setq mark-regexp (regexp-quote elmo-msgdb-new-mark)))
      (unread
       (setq mark-regexp (elmo-regexp-opt (elmo-msgdb-unread-marks))))
      (answered
       (setq mark-regexp (elmo-regexp-opt (elmo-msgdb-answered-marks))))
      (important
       (setq mark-regexp (regexp-quote elmo-msgdb-important-mark)))
      (read
       (setq mark-regexp (elmo-regexp-opt (elmo-msgdb-unread-marks))))
      (digest
       (setq mark-regexp (elmo-regexp-opt
			  (append (elmo-msgdb-unread-marks)
				  (list elmo-msgdb-important-mark)))))
      (any
       (setq mark-regexp (elmo-regexp-opt
			  (append
			   (elmo-msgdb-unread-marks)
			   (elmo-msgdb-answered-marks)
			   (list elmo-msgdb-important-mark))))))
    (when mark-regexp
      (if (eq flag 'read)
	  (dolist (number (elmo-msgdb-list-messages msgdb))
	    (let ((mark (elmo-msgdb-get-mark msgdb number)))
	      (unless (and mark (string-match mark-regexp mark))
		(setq matched (cons number matched)))))
	(dolist (elem (elmo-msgdb-get-mark-alist msgdb))
	  (if (string-match mark-regexp (cadr elem))
	      (setq matched (cons (car elem) matched))))))
    matched))

(require 'product)
(product-provide (provide 'elmo-msgdb) (require 'elmo-version))

;;; elmo-msgdb.el ends here
