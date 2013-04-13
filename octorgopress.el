;; Octopress backend for Org-mode
;; Depends on latest (bleeding development branch, maybe v8.x) of Org
;; uses generic export: http://orgmode.org/worg/dev/org-export-reference.html

(require 'ox)

(defvar *org-octopress-yaml-front-matter* t)

(org-export-define-backend 'octopress
  '(
    (bold . org-octopress-bold)
    (fixed-width . org-octopress-fixed-width)
    (headline . org-octopress-headline)
    (italic . org-octopress-italic)
    (link . org-octopress-link)
    (paragraph . org-octopress-paragraph)
    (section . org-octopress-section)
    (src-block . org-octopress-src-block)
    (template . org-octopress-template)
))

(defun org-octopress-template (contents info)
  "Accepts the final transcoded string and a plist of export options,
returns final string with YAML frontmatter as preamble"
  (let ((title (car (plist-get info :title)))
        (date (car (plist-get info :date)))
        (time "")
        (frontmatter
"---
layout: post
title: %s
date: %s %s
comments: true
external-url:
categories:
---
"))
    (if *org-octopress-yaml-front-matter*
        (concat (format frontmatter title date time) contents)
      contents)))

(defun org-octopress-src-block (src-block contents info)
  "Transcode a #+begin_src block from Org to Github style backtick code blocks"
  (let* ((lang (org-element-property :language src-block))
         (value (org-element-property :value src-block))
         (name (org-element-property :name src-block))
         (lang-and-name (or (and lang name (format " %s %s\n" lang name)) "\n")))
    (concat
     "```"
     lang-and-name
     value
     "```\n"
     contents)))

(defun repeat (x n)
  (let (acc)
    (dotimes (_ n acc)
      (push x acc))))

(defun org-octopress-headline (headline contents info)
  (let ((value (org-element-property :raw-value headline))
        (level (org-element-property :level headline)))
    (concat (apply 'concat (repeat "#" level))
            " "
            value
            "\n"
            contents)))

(defun org-octopress-link (link contents info)
  (let ((path (org-element-property :raw-link link)))
    (format "[%s](%s)" contents path)))

(defun org-octopress-paragraph (paragraph contents info)
  contents)

(defun org-octopress-section (section contents info)
  contents)

(defun org-octopress-italic (elt contents info)
  "Transcode italic text to Octopress equiv of <em>"
  (format "*%s*" contents))

(defun org-octopress-bold (text contents info)
  "Transcode bold text to Octopress equiv of <strong>"
  (format "**%s**" contents))

(defun is-empty (s)
  (string= s ""))

(defun drop-while (f list)
  (cond ((null list) nil)
        ((funcall f (car list)) (drop-while f (cdr list)))
        (t list)))

(defun take-while (f list)
  (cond ((null list) nil)
        ((funcall f (car list)) (cons (car list)
                                      (take-while f (cdr list))))
        (t nil)))

(defun complement (f)
  (lexical-let ((f f))
    (lambda (&rest args)
      (not (apply f args)))))

(defun string-join (xs y)
  (mapconcat #'identity xs y))

(defun trim-empty-lines (s)
  (let ((lines (split-string s "\n")))
    (string-join
     (reverse (drop-while #'is-empty
                          (reverse (drop-while #'is-empty lines)))) "\n")))

(defun org-octopress-fixed-width (fixed-width contents info)
  "Transcode fixed-width region to Octopress anonymous code block"
  (concat "```\n"
          (trim-empty-lines (org-element-property :value fixed-width))
          "\n```\n"))

(defun org-octopress-export-as-octopress
  (&optional async subtreep visible-only body-only ext-plist)
  (interactive)
  (if async
      (org-export-async-start
          (lambda (output)
            (with-current-buffer (get-buffer-create "*Org Octopress Export*")
              (erase-buffer)
              (insert output)
              (goto-char (point-min))
              (org-export-add-to-stack (current-buffer) 'octopress)))
        `(org-export-as 'octopress ,subtreep ,visible-only ,body-only ',ext-plist))
    (let ((outbuf (org-export-to-buffer 'octopress "*Org Octopress Export*"
                                        subtreep visible-only body-only ext-plist)))
      (with-current-buffer outbuf (LaTeX-mode))
      (when org-export-show-temporary-export-buffer
        (switch-to-buffer-other-window outbuf)))))

(defun org-octopress-publish-to-octopress (plist filename pub-dir)
  (org-publish-org-to 'octopress filename ".md" plist pub-dir))

(defun new-post (dir title)
  "Create and visit a new .org file in dir named $date-$title.org, ie
Octopress/Jekyll style"
  (interactive "Mdirectory: \nMtitle: ")
  (let* ((date (format-time-string "%Y-%m-%d"))
         (title-no-spaces (replace-regexp-in-string " +" "-" title))
         (dirname (file-name-as-directory dir))
         (filename (format (concat dirname "%s-%s.org") date title-no-spaces)))
    (find-file filename)
    (rename-buffer title)
    (org-insert-export-options-template)
    (rename-buffer filename)))

(defun make-org-publish-project-alist
  (name blorg-root octopress-root)
  (let ((octopress-posts (concat (file-name-as-directory octopress-root)
                                 "source/_posts")))
    `(("posts"
       :base-directory ,blorg-root
       :base-extension "org"
       :publishing-directory ,octopress-posts
       :publishing-function org-octopress-publish-to-octopress)
      (,name :components ("posts")))))
