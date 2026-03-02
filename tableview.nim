## Compatibility shim: Nimble adds the package root to ``--path`` for
## dependent projects without appending the ``src/`` suffix.
## This stub makes ``import tableview`` resolve for external projects.
##
## ``include`` keeps module resolution consistent for imports used by
## ``src/tableview.nim`` (including ``tableview/parser``).
## ``include`` resolves relative to *this* file's directory, so
## ``src/tableview.nim`` is always found regardless of the working directory.
include src/tableview
