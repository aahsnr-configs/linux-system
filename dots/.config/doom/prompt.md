**Text** 

In my current proposed workflow, I want to do python programming in jupyter notebooks but instead of using jupyter notebooks, I intend to use org-mode with the emacs-jupyter package to mimic the features of jupyter notebooks in general.
I indent to preserve the context between the source code blocks, especially for jupyter-python source code blocks. In other words, lets 

The link https://raw.githubusercontent.com/minad/corfu/refs/heads/main/extensions/corfu-popupinfo.el is a current file for the corfu-popupinfo extension in corfu. My attached doom emacs configuration is giving the error in the attached screenshot. Search the web, and the link to find a solution.

For the attached doom emacs configuration files, is the solution in LSP IN ORG SOURCE BLOCKS inspired by https://raw.githubusercontent.com/gav451/oglot/refs/heads/main/oglot.el enough for an efficient literate python programming using emacs-jupyter and org-mode? Or do I need to use the oglot package direclty? Keep in mind that this package an year old and has not be been updated for that time period. Make any necessary changes as you see fit. But make sure to only use emacs and doom-emacs best practices and also make sure to use up-to-date information and changes.

- [ ] For the attached doom emacs configuration files, the section titled LSP in Org Source Blocks is meant to help org source code blocks retain context from the whole tangled python source code block, so that diagnostics, completions and other lsp features that are typically available for a specific python file is also available to buffers opened by org-edit-special or org-edit-src-code. LSP servers need access to a file that it's running on that it provides all the lsp server capabilities to this file. Org src buffers typically are not associated with files, but that section tried to fill the gap by drawing context from a tangled file that contained all the contents from the tangled source code files. Each of the source code block typically associated with the same file to achieve this. This was done for eglot. 

The attached lsp-bridge-org-babel.el is a version of how to achieve the above intended functionalities. Thoroughly research the web and make sure the implementation is correct and free of issues. Then guide me how to implement this to my doom emacs configuration config.org file.
