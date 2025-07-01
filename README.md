# 📌 Open Banking Fintech Database Design

A highly-normalized, ACID-compliant PostgreSQL schema for an Open Banking platform that lets users aggregate multiple bank accounts, view balances & transaction history, and optionally initiate payments via third-party APIs.

---

## 📖 Introduction

Open Banking enables secure, standardized access to bank data via APIs. This design supports a fintech application where users can:
- **Link** deposit, credit-card or investment accounts across multiple banks  
- **View** consolidated balances and recent transactions  
- **Drill-down** on transaction history with date/amount filters  
- **(Optionally) Initiate** bill payments & internal transfers  

---

## 👥 User Requirements

1. **Account Linking**  
2. **Account Viewing**  
3. **Transaction History**  
4. **Transfer Money**  

---

## 🌐 Data Model & Schema

### Entities & Relationships
<img src="https://github.com/meteahmetyakar/OpenBanking-Database-System/blob/main/images/ER-diagram.png"/>

- **Customer (1)–(N) Account**  
- **Bank (1)–(N) Account**  
- **Account (1)–(N) Transaction**  
- **Customer (M)–(N) Bank** via **Consent**

### Inheritance & Weak Entities

- **Subtype Tables**:  
  - `checking_accounts` (`account_id` PK) with `overdraft_limit`  
  - `savings_accounts` (`account_id` PK) with `interest_rate`  
  - `credit_card_accounts` (`account_id` PK) with `credit_limit`  
- **Weak Entity**:  
  - `account_beneficiaries` with composite PK (`account_id`, `beneficiary_id`)

---

## 🗄️ Logical Schema (DDL Snippets)

```sql
CREATE TABLE customers (...);
CREATE TABLE banks (...);
CREATE TABLE accounts (...);
CREATE TABLE consents (...);
CREATE TABLE transactions (...);

-- Subtype Inheritance
CREATE TABLE checking_accounts (
  account_id INT PRIMARY KEY REFERENCES accounts(account_id),
  overdraft_limit NUMERIC
);
-- similar for savings_accounts, credit_card_accounts

-- Weak Entity
CREATE TABLE account_beneficiaries (
  account_id INT REFERENCES accounts(account_id) ON DELETE CASCADE,
  beneficiary_id INT,
  name TEXT,
  PRIMARY KEY (account_id, beneficiary_id)
);
```

---

## ⚙️ Triggers & Business Logic

- **`trg_check_account_status`**  
   - **When**: BEFORE INSERT on `transactions`  
   - **Purpose**: Reject if target account `status <> 'active'`.

- **`trg_check_balance`**  
   - **When**: BEFORE INSERT on `transactions`  
   - **Purpose**: For withdrawals/transfers, rollback if `amount > balance`.

- **`trg_update_balance`**  
   - **When**: AFTER INSERT/UPDATE/DELETE on `transactions`  
   - **Purpose**: Increment/decrement `accounts.balance` exactly once per row.

- **`trg_prevent_overdraft`**  
   - **When**: AFTER UPDATE on `accounts` (FOLLOWS `trg_update_balance`)  
   - **Purpose**: Raise exception if new balance `< 0`.

- **`trg_audit_transactions`**  
   - **When**: AFTER INSERT/UPDATE/DELETE on `transactions`  
   - **Purpose**: Insert old/new row data into `transactions_audit`.

- **`trg_notify_new_transaction`**  
   - **When**: AFTER INSERT on `transactions`  
   - **Purpose**: Issue `pg_notify('new_tx', json_build_object(...))`.

- **`trg_cascade_bank_code`**  
   - **When**: AFTER UPDATE on `banks`  
   - **Purpose**: Propagate `bank_code` changes to denormalized child columns.

---

## 🔎 Views

- **`vw_recent_transactions`**: Latest N rows per account (uses `ROW_NUMBER()` window).  
- **`vw_account_summary`**: Total count, sum credit/debit per account.  
- **`vw_masked_accounts`**: Shows `****1234` masked account numbers.  
- **`vw_active_consents`**: Only currently valid consents.  
- **`vw_customer_account_summary`**: Per-customer account count & total balance.

---

## 🛠️ Functions

- **`fn_update_balance()`**  
  - **Type**: TRIGGER FUNCTION  
  - **Purpose**: Adjust account balance after transaction.

- **`fn_prevent_overdraft()`**  
  - **Type**: TRIGGER FUNCTION  
  - **Purpose**: Enforce no-negative balances.

- **`fn_audit_transactions()`**  
  - **Type**: TRIGGER FUNCTION  
  - **Purpose**: Record audit trail.

- **`fn_notify_new_transaction()`**  
  - **Type**: TRIGGER FUNCTION  
  - **Purpose**: Send `NOTIFY` for UI.

- **`transfer_funds(src_acc INT, dst_acc INT, amt NUMERIC)`**  
  - **Type**: IMMUTABLE PROCEDURE  
  - **Purpose**: Atomic debit & credit pair.

- **`mask_account_number(acc_no TEXT)`**  
  - **Type**: IMMUTABLE FUNCTION  
  - **Returns**: TEXT  
  - **Purpose**: Return masked string.

---

## 🔒 Security & Roles

- `app_user`, `analyst`, `dba` with least-privilege grants.  
- Potential row-level security for per-customer isolation.

---

## 🛡️ Concurrency Control

- **MVCC**, **Serializable** isolation option, **Row-level locks** in `transfer_funds`.  
- **Trigger ordering** ensures atomic updates.

---

## 🖥️ User Interfaces

- **WinForms / React-Admin** front-end.  
- **PostgREST** API endpoints.  
- **Admin dashboards** for bank & consent management.  
- **Log viewer** for audit inspection.

---

## ✅ Conclusion

Comprehensive PostgreSQL design featuring normalized schema, subtype inheritance, triggers, functions, views, and robust business logic—ensuring security, integrity, and real-time notifications.

