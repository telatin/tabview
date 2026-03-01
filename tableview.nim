## Compatibility shim: Nimble adds the package root to ``--path`` for
## dependent projects, so this file makes ``import tableview`` resolve
## even though the implementation lives in ``src/tableview.nim``.
import src/tableview as tv
export tv
