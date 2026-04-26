#!/usr/bin/env python3
"""
Build and install Emacs 30.2 with Pure GTK (Wayland) on openSUSE Tumbleweed.

This script:
  - Installs build dependencies via `zypper si -d --no-recommends emacs`
  - Downloads and verifies the source tarball
  - Applies two required compatibility patches (tree-sitter 0.26, query predicates)
  - Configures with PGTK, ImageMagick, native compilation, and tree-sitter
  - Builds with `make bootstrap -j<N>`
  - Installs system-wide (by default into /usr) and resolves ctags conflicts

All command outputs are streamed live to the terminal.
"""

import argparse
import logging
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

# ----------------------------------------------------------------------
# Embedded patch files (content from Gentoo/Arch build recipes)
# ----------------------------------------------------------------------
PATCH_TREESIT_0_26 = r"""Fix compilation with tree-sitter 0.26
Patch backported from master branch (omitting WINDOWSNT parts)
https://bugs.gentoo.org/970856

commit d587ce8c65a0e22ab0a63ef2873a3dfcfbeba166
Author: Eli Zaretskii <eliz@gnu.org>
Date:   Fri Oct 17 14:15:41 2025 +0300

    Support Tree-sitter version 0.26 and later

--- emacs-30.2/src/treesit.c
+++ emacs-30.2/src/treesit.c
@@ -632,6 +632,22 @@
     }
 }
 
+/* This function is a compatibility shim.  Tree-sitter 0.25 introduced
+   ts_language_abi_version as a replacement for ts_language_version, and
+   tree-sitter 0.26 removed ts_language_version.  Here we use the fact
+   that 0.25 bumped TREE_SITTER_LANGUAGE_VERSION to 15, to use the new
+   function instead of the old one, when Emacs is compiled against
+   tree-sitter version 0.25 or newer.  */
+static uint32_t
+treesit_language_abi_version (const TSLanguage *ts_lang)
+{
+#if TREE_SITTER_LANGUAGE_VERSION >= 15
+  return ts_language_abi_version (ts_lang);
+#else
+  return ts_language_version (ts_lang);
+#endif
+}
+
 /* Load the dynamic library of LANGUAGE_SYMBOL and return the pointer
    to the language definition.
 
@@ -746,7 +762,7 @@
     {
       *signal_symbol = Qtreesit_load_language_error;
       *signal_data = list2 (Qversion_mismatch,
-			    make_fixnum (ts_language_version (lang)));
+			    make_fixnum (treesit_language_abi_version (lang)));
       return NULL;
     }
   return lang;
@@ -817,7 +833,7 @@
 						       &signal_data);
       if (ts_language == NULL)
 	return Qnil;
-      uint32_t version =  ts_language_version (ts_language);
+      uint32_t version =  treesit_language_abi_version (ts_language);
       return make_fixnum((ptrdiff_t) version);
     }
 }
"""

PATCH_QUERY_PRED = r"""Fix query predicate names for tree-sitter-0.26
Patch backported from master branch
https://bugs.gentoo.org/971731

commit b01435306a36e4e75671fbe7bacea351f89947d5
Author: Yuan Fu <casouri@gmail.com>
Date:   Sun, 2 Nov 2025 16:16:50 -0800

    Change tree-sitter query predicate names (bug#79687)

--- emacs-30.2/doc/lispref/parsing.texi
+++ emacs-30.2/doc/lispref/parsing.texi
@@ -1375,7 +1375,7 @@
 @group
 (
  (array :anchor (_) @@first (_) @@last :anchor)
- (:equal @@first @@last)
+ (:eq? @@first @@last)
 )
 @end group
 @end example
@@ -1384,24 +1384,32 @@
 tree-sitter only matches arrays where the first element is equal to
 the last element.  To attach a predicate to a pattern, we need to
 group them together.  Currently there are three predicates:
-@code{:equal}, @code{:match}, and @code{:pred}.
+@code{:eq?}, @code{:match?}, and @code{:pred?}.
 
-@deffn Predicate :equal arg1 arg2
+@deffn Predicate :eq? arg1 arg2
 Matches if @var{arg1} is equal to @var{arg2}.  Arguments can be either
 strings or capture names.  Capture names represent the text that the
-captured node spans in the buffer.
+captured node spans in the buffer.  Note that this is more like
+@code{equal} in Elisp, but @code{eq?} is the convention used by
+tree-sitter.  Previously we supported the @code{:equal} predicate but
+it's now considered deprecated.
 @end deffn
 
-@deffn Predicate :match regexp capture-name
+@deffn Predicate :match? capture-name regexp
 Matches if the text that @var{capture-name}'s node spans in the buffer
 matches regular expression @var{regexp}, given as a string literal.
-Matching is case-sensitive.
+Matching is case-sensitive.  The ordering of the arguments doesn't
+matter.  Previously we supported the @code{:match} predicate but it's
+now considered deprecated.
 @end deffn
 
-@deffn Predicate :pred fn &rest nodes
+@deffn Predicate :pred? fn &rest nodes
 Matches if function @var{fn} returns non-@code{nil} when passed each
 node in @var{nodes} as arguments.  The function runs with the current
-buffer set to the buffer of node being queried.
+buffer set to the buffer of node being queried.  Be very careful when
+using this predicate, since it can be expensive when used in a tight
+loop.  Previously we supported the @code{:pred} predicate but it's now
+considered deprecated.
 @end deffn
 
 Note that a predicate can only refer to capture names that appear in
@@ -1456,9 +1464,9 @@
 @item
 @samp{:+} is written as @samp{+}.
 @item
-@code{:equal}, @code{:match} and @code{:pred} are written as
-@code{#equal}, @code{#match} and @code{#pred}, respectively.
-In general, predicates change their @samp{:} to @samp{#}.
+@code{:eq?}, @code{:match?} and @code{:pred?} are written as
+@code{#eq?}, @code{#match?} and @code{#pred?}, respectively.  In
+general, predicates change the @samp{:} to @samp{#}.
 @end itemize
 
 For example,
@@ -1467,7 +1475,7 @@
 @group
 '((
    (compound_expression :anchor (_) @@first (_) :* @@rest)
-   (:match "love" @@first)
+   (:match? "love" @@first)
    ))
 @end group
 @end example
@@ -1479,7 +1487,7 @@
 @group
 "(
   (compound_expression . (_) @@first (_)* @@rest)
-  (#match \"love\" @@first)
+  (#match? \"love\" @@first)
   )"
 @end group
 @end example
--- emacs-30.2/src/treesit.c
+++ emacs-30.2/src/treesit.c
@@ -415,17 +415,17 @@
 static Lisp_Object Vtreesit_str_question_mark;
 static Lisp_Object Vtreesit_str_star;
 static Lisp_Object Vtreesit_str_plus;
-static Lisp_Object Vtreesit_str_pound_equal;
-static Lisp_Object Vtreesit_str_pound_match;
-static Lisp_Object Vtreesit_str_pound_pred;
+static Lisp_Object Vtreesit_str_pound_eq_question_mark;
+static Lisp_Object Vtreesit_str_pound_match_question_mark;
+static Lisp_Object Vtreesit_str_pound_pred_question_mark;
 static Lisp_Object Vtreesit_str_open_bracket;
 static Lisp_Object Vtreesit_str_close_bracket;
 static Lisp_Object Vtreesit_str_open_paren;
 static Lisp_Object Vtreesit_str_close_paren;
 static Lisp_Object Vtreesit_str_space;
-static Lisp_Object Vtreesit_str_equal;
-static Lisp_Object Vtreesit_str_match;
-static Lisp_Object Vtreesit_str_pred;
+static Lisp_Object Vtreesit_str_eq_question_mark;
+static Lisp_Object Vtreesit_str_match_question_mark;
+static Lisp_Object Vtreesit_str_pred_question_mark;
 static Lisp_Object Vtreesit_str_empty;
 
 /* This is the limit on recursion levels for some tree-sitter
@@ -2620,12 +2620,12 @@
     return Vtreesit_str_star;
   if (BASE_EQ (pattern, QCplus))
     return Vtreesit_str_plus;
-  if (BASE_EQ (pattern, QCequal))
-    return Vtreesit_str_pound_equal;
-  if (BASE_EQ (pattern, QCmatch))
-    return Vtreesit_str_pound_match;
-  if (BASE_EQ (pattern, QCpred))
-    return Vtreesit_str_pound_pred;
+  if (BASE_EQ (pattern, QCequal) || BASE_EQ (pattern, QCeq_q))
+    return Vtreesit_str_pound_eq_question_mark;
+  if (BASE_EQ (pattern, QCmatch) || BASE_EQ (pattern, QCmatch_q))
+    return Vtreesit_str_pound_match_question_mark;
+  if (BASE_EQ (pattern, QCpred) || BASE_EQ (pattern, QCpred_q))
+    return Vtreesit_str_pound_pred_question_mark;
   Lisp_Object opening_delimeter
     = VECTORP (pattern)
       ? Vtreesit_str_open_bracket : Vtreesit_str_open_paren;
@@ -2656,7 +2656,9 @@
     :*
     :+
     :equal
+    :eq?
     :match
+    :match?
     (TYPE PATTERN...)
     [PATTERN...]
     FIELD-NAME:
@@ -2819,7 +2821,7 @@
   return !NILP (Fstring_equal (text1, text2));
 }
 
-/* Handles predicate (#match "regexp" @node).  Return true if "regexp"
+/* Handles predicate (#match? "regexp" @node).  Return true if "regexp"
    matches the text spanned by @node; return false otherwise.
    Matching is case-sensitive.  If everything goes fine, don't touch
    SIGNAL_DATA; if error occurs, set it to a suitable signal data.  */
@@ -2829,26 +2831,24 @@
 {
   if (list_length (args) != 2)
     {
-      *signal_data = list2 (build_string ("Predicate `match' requires two "
+      *signal_data = list2 (build_string ("Predicate `match?' requires two "
 					  "arguments but got"),
 			    Flength (args));
       return false;
     }
-  Lisp_Object regexp = XCAR (args);
-  Lisp_Object capture_name = XCAR (XCDR (args));
+  Lisp_Object arg1 = XCAR (args);
+  Lisp_Object arg2 = XCAR (XCDR (args));
+  Lisp_Object regexp = SYMBOLP (arg2) ? arg1 : arg2;
+  Lisp_Object capture_name = SYMBOLP (arg2) ? arg2 : arg1;
 
-  /* It's probably common to get the argument order backwards.  Catch
-     this mistake early and show helpful explanation, because Emacs
-     loves you.  (We put the regexp first because that's what
-     string-match does.)  */
-  if (!STRINGP (regexp))
-    xsignal1 (Qtreesit_query_error,
-	      build_string ("The first argument to `match' should "
-		            "be a regexp string, not a capture name"));
-  if (!SYMBOLP (capture_name))
-    xsignal1 (Qtreesit_query_error,
-	      build_string ("The second argument to `match' should "
-		            "be a capture name, not a string"));
+  if (!STRINGP (regexp) || !SYMBOLP (capture_name))
+    {
+      *signal_data = list2 (build_string ("Predicate `match?' takes a regexp "
+	                                  "and a node capture (order doesn't "
+					  "matter), but got"),
+			    Flength (args));
+      return false;
+    }
 
   Lisp_Object node = Qnil;
   if (!treesit_predicate_capture_name_to_node (capture_name, captures, &node,
@@ -2932,11 +2932,11 @@
       Lisp_Object predicate = XCAR (tail);
       Lisp_Object fn = XCAR (predicate);
       Lisp_Object args = XCDR (predicate);
-      if (!NILP (Fstring_equal (fn, Vtreesit_str_equal)))
+      if (!NILP (Fstring_equal (fn, Vtreesit_str_eq_question_mark)))
 	pass &= treesit_predicate_equal (args, captures, signal_data);
-      else if (!NILP (Fstring_equal (fn, Vtreesit_str_match)))
+      else if (!NILP (Fstring_equal (fn, Vtreesit_str_match_question_mark)))
 	pass &= treesit_predicate_match (args, captures, signal_data);
-      else if (!NILP (Fstring_equal (fn, Vtreesit_str_pred)))
+      else if (!NILP (Fstring_equal (fn, Vtreesit_str_pred_question_mark)))
 	pass &= treesit_predicate_pred (args, captures, signal_data);
       else
 	{
@@ -4208,8 +4208,11 @@
   DEFSYM (QCstar, ":*");
   DEFSYM (QCplus, ":+");
   DEFSYM (QCequal, ":equal");
+  DEFSYM (QCeq_q, ":eq?");
   DEFSYM (QCmatch, ":match");
+  DEFSYM (QCmatch_q, ":match?");
   DEFSYM (QCpred, ":pred");
+  DEFSYM (QCpred_q, ":pred?");
 
   DEFSYM (Qnot_found, "not-found");
   DEFSYM (Qsymbol_error, "symbol-error");
@@ -4340,12 +4343,12 @@
   Vtreesit_str_star = build_pure_c_string ("*");
   staticpro (&Vtreesit_str_plus);
   Vtreesit_str_plus = build_pure_c_string ("+");
-  staticpro (&Vtreesit_str_pound_equal);
-  Vtreesit_str_pound_equal = build_pure_c_string ("#equal");
-  staticpro (&Vtreesit_str_pound_match);
-  Vtreesit_str_pound_match = build_pure_c_string ("#match");
-  staticpro (&Vtreesit_str_pound_pred);
-  Vtreesit_str_pound_pred = build_pure_c_string ("#pred");
+  staticpro (&Vtreesit_str_pound_eq_question_mark);
+  Vtreesit_str_pound_eq_question_mark = build_pure_c_string ("#eq?");
+  staticpro (&Vtreesit_str_pound_match_question_mark);
+  Vtreesit_str_pound_match_question_mark = build_pure_c_string ("#match?");
+  staticpro (&Vtreesit_str_pound_pred_question_mark);
+  Vtreesit_str_pound_pred_question_mark = build_pure_c_string ("#pred?");
   staticpro (&Vtreesit_str_open_bracket);
   Vtreesit_str_open_bracket = build_pure_c_string ("[");
   staticpro (&Vtreesit_str_close_bracket);
@@ -4356,12 +4359,12 @@
   Vtreesit_str_close_paren = build_pure_c_string (")");
   staticpro (&Vtreesit_str_space);
   Vtreesit_str_space = build_pure_c_string (" ");
-  staticpro (&Vtreesit_str_equal);
-  Vtreesit_str_equal = build_pure_c_string ("equal");
-  staticpro (&Vtreesit_str_match);
-  Vtreesit_str_match = build_pure_c_string ("match");
-  staticpro (&Vtreesit_str_pred);
-  Vtreesit_str_pred = build_pure_c_string ("pred");
+  staticpro (&Vtreesit_str_eq_question_mark);
+  Vtreesit_str_eq_question_mark = build_pure_c_string ("eq?");
+  staticpro (&Vtreesit_str_match_question_mark);
+  Vtreesit_str_match_question_mark = build_pure_c_string ("match?");
+  staticpro (&Vtreesit_str_pred_question_mark);
+  Vtreesit_str_pred_question_mark = build_pure_c_string ("pred?");
   staticpro (&Vtreesit_str_empty);
   Vtreesit_str_empty = build_pure_c_string ("");
 
--- emacs-30.2/test/src/treesit-tests.el
+++ emacs-30.2/test/src/treesit-tests.el
@@ -434,10 +434,10 @@
                ;; String query.
                '("(string) @string
 (pair key: (_) @keyword)
-((_) @bob (#match \"\\\\`B.b\\\\'\" @bob))
+((_) @bob (#match? \"\\\\`B.b\\\\'\" @bob))
 (number) @number
-((number) @n3 (#equal \"3\" @n3))
-((number) @n3p (#pred treesit--ert-pred-last-sibling @n3p))"
+((number) @n3 (#eq? \"3\" @n3))
+((number) @n3p (#pred? treesit--ert-pred-last-sibling @n3p))"
                  ;; Sexp query.
                  ((string) @string
                   (pair key: (_) @keyword)
"""

# ----------------------------------------------------------------------
# Logging & helpers
# ----------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# Sentinel file to mark that patches have been applied
PATCH_SENTINEL = ".emacs_build_patches_applied"


def run_cmd_live(cmd, cwd=None, env=None, sudo=False, check=True):
    """
    Run a command, streaming its output live to stdout.
    If *check* is True, the script exits on non-zero return code.
    Returns the return code of the process.
    """
    if sudo:
        cmd = ["sudo"] + cmd
    log.info("Running: %s", " ".join(cmd))
    returncode = 0
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        # Stream output line by line
        for line in proc.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
        proc.wait()
        returncode = proc.returncode
        if returncode != 0:
            if check:
                log.error("Command failed with exit code %d", returncode)
                sys.exit(1)
            else:
                log.warning("Command failed with exit code %d (ignored)", returncode)
    except FileNotFoundError:
        log.error("Command not found: %s", cmd[0])
        if check:
            sys.exit(1)
    except Exception as e:
        log.error("Unexpected error running command: %s", e)
        if check:
            sys.exit(1)
    return returncode


def apply_patches(source_dir: Path) -> None:
    """Apply both patches if not already applied (checked via sentinel file)."""
    sentinel = source_dir / PATCH_SENTINEL
    if sentinel.exists():
        log.info("Patches already applied (sentinel %s exists), skipping.", PATCH_SENTINEL)
        return

    log.info("Applying patches to source tree...")

    # Helper to apply a single patch from content
    def _apply(patch_content, description):
        log.info("Applying patch: %s", description)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".patch", delete=False) as f:
            f.write(patch_content)
            patch_path = f.name
        try:
            # patch -Np1 ensures we don't reverse apply, fails if already applied
            run_cmd_live(["patch", "-Np1", "-i", patch_path], cwd=source_dir)
        finally:
            Path(patch_path).unlink()

    _apply(PATCH_TREESIT_0_26, "tree-sitter 0.26 compatibility")
    _apply(PATCH_QUERY_PRED, "query predicate names")

    # Create sentinel file to mark success
    sentinel.touch()
    log.info("Patches applied successfully.")


def download(url: str, dest: Path) -> None:
    """Download a file if it does not exist."""
    if dest.exists():
        log.info("File %s already exists, skipping download.", dest.name)
        return
    log.info("Downloading %s -> %s", url, dest.name)
    try:
        urllib.request.urlretrieve(url, dest)
    except Exception as e:
        log.error("Download failed: %s", e)
        sys.exit(1)


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Build Emacs 30.2 with PGTK on openSUSE")
    parser.add_argument("--work-dir", default=Path.cwd() / "emacs-build", type=Path,
                        help="Directory for downloading and building (default: ./emacs-build)")
    parser.add_argument("--keep", action="store_true", help="Keep build directory after installation")
    parser.add_argument("--skip-deps", action="store_true", help="Skip dependency installation")
    parser.add_argument("--no-verify", action="store_true", help="Skip signature verification")
    parser.add_argument("--verify-strict", action="store_true",
                        help="Abort if GPG verification fails (default: warn only)")
    parser.add_argument("--jobs", "-j", type=int, default=12, help="Number of parallel make jobs (default: 12)")
    parser.add_argument("--prefix", default="/usr", help="Installation prefix (default: /usr)")
    args = parser.parse_args()

    # Use pathlib for all path operations
    work_dir = args.work_dir.resolve()
    source_dir = work_dir / "emacs-30.2"
    tarball = work_dir / "emacs-30.2.tar.xz"
    sig_file = work_dir / "emacs-30.2.tar.xz.sig"

    # Step 1: Ensure work directory exists
    work_dir.mkdir(parents=True, exist_ok=True)

    # Step 2: Install build dependencies (idempotent; safe to re-run)
    if not args.skip_deps:
        log.info("Installing build dependencies via zypper")
        run_cmd_live(["zypper", "si", "-d", "--no-recommends", "emacs"], sudo=True)

    # Step 3: Download source tarball and signature (only if missing)
    base_url = "https://ftp.gnu.org/gnu/emacs/"
    download(base_url + "emacs-30.2.tar.xz", tarball)
    if not args.no_verify:
        download(base_url + "emacs-30.2.tar.xz.sig", sig_file)

    # Step 4: Verify signature (optional)
    if not args.no_verify:
        log.info("Verifying GPG signature")
        # Import known good keys (failure is not fatal)
        for keyid in ["17E90D521672C04631B1183EE78DAE0F3115E06B",
                      "CEA1DE21AB108493CC9C65742E82323B8F4353EE"]:
            run_cmd_live(["gpg", "--recv-keys", keyid], check=False)
        # Verify; if strict, failure causes exit, else just warn
        ret = run_cmd_live(["gpg", "--verify", str(sig_file), str(tarball)], check=False)
        if ret != 0:
            if args.verify_strict:
                log.error("Strict verification requested and GPG check failed. Aborting.")
                sys.exit(1)
            else:
                log.warning("GPG verification failed, continuing anyway.")

    # Step 5: Extract tarball (only if source directory does not exist)
    if not source_dir.exists():
        log.info("Extracting tarball...")
        with tarfile.open(tarball) as tar:
            tar.extractall(work_dir)
        if not source_dir.is_dir():
            log.error("Extraction failed – source directory not found: %s", source_dir)
            sys.exit(1)
    else:
        log.info("Source directory %s already exists, skipping extraction.", source_dir)

    # Step 6: Apply patches (idempotent via sentinel file)
    apply_patches(source_dir)

    # Step 7: Configure (re-running configure is safe and necessary)
    configure_flags = [
        f"--prefix={args.prefix}",
        "--sysconfdir=/etc",
        "--libexecdir=/usr/lib",
        "--localstatedir=/var",
        "--disable-build-details",
        "--with-cairo",
        "--with-harfbuzz",
        "--with-libsystemd",
        "--with-modules",
        "--with-native-compilation=aot",
        "--with-tree-sitter",
        "--with-pgtk",
        "--with-imagemagick",
    ]
    env = os.environ.copy()
    env["ac_cv_lib_gif_EGifPutExtensionLast"] = "yes"
    log.info("Configuring Emacs with PGTK")
    run_cmd_live(["./configure"] + configure_flags, cwd=source_dir, env=env)

    # Step 8: Build (make bootstrap is idempotent; it will rebuild what's needed)
    log.info("Building Emacs (make bootstrap -j%d)", args.jobs)
    run_cmd_live(["make", "bootstrap", f"-j{args.jobs}"], cwd=source_dir)

    # Step 9: Install (make install is idempotent; will replace existing files)
    log.info("Installing Emacs to %s", args.prefix)
    run_cmd_live(["make", "install"], cwd=source_dir, sudo=True)

    # Step 10: Post-install adjustments (idempotent, safe to re-run)
    if args.prefix == "/usr":
        bin_ctags = Path("/usr/bin/ctags")
        bin_ctags_new = bin_ctags.with_name("ctags.emacs")
        if bin_ctags.exists() and not bin_ctags_new.exists():
            log.info("Renaming /usr/bin/ctags -> ctags.emacs")
            run_cmd_live(["mv", str(bin_ctags), str(bin_ctags_new)], sudo=True)
        elif bin_ctags_new.exists():
            log.info("/usr/bin/ctags.emacs already exists, skipping rename.")

        # Man page (could be .gz or plain)
        man1_dir = Path("/usr/share/man/man1")
        for man_src in [man1_dir / "ctags.1.gz", man1_dir / "ctags.1"]:
            if man_src.exists():
                man_dst = man_src.with_name("ctags.emacs.1.gz" if man_src.suffix == ".gz" else "ctags.emacs.1")
                if not man_dst.exists():
                    log.info("Renaming %s -> %s", man_src, man_dst)
                    run_cmd_live(["mv", str(man_src), str(man_dst)], sudo=True)
                else:
                    log.info("%s already exists, skipping rename.", man_dst)
                break  # only one version should exist

        # Fix ownership
        emacs_share = Path("/usr/share/emacs/30.2")
        if emacs_share.exists():
            log.info("Ensuring root ownership of %s", emacs_share)
            run_cmd_live(["chown", "-R", "root:root", str(emacs_share)], sudo=True)
    else:
        log.info("Skipping ctags/post-install adjustments for non-/usr prefix")

    # Step 11: Cleanup
    if not args.keep:
        log.info("Removing build directory: %s", work_dir)
        shutil.rmtree(work_dir, ignore_errors=True)
    else:
        log.info("Build directory kept at: %s", work_dir)

    log.info("Emacs 30.2 with PGTK successfully installed.")


if __name__ == "__main__":
    main()