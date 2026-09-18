# Sales invoice — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SI1 | doc_wrong | ACs `[ ]` | Issue/return RPCs shipped (`create_sales_invoice_from_payload`, `process_wholesale_invoice_return`) | Tick matching ACs |
| SI2 | doc_wrong | Older docs may say invoice status `posted` | Live status is `issued` | Never resurrect `posted` in SQL or PRD |
