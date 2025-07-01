--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Drop databases (except postgres and template1)
--

DROP DATABASE open_banking;




--
-- Drop roles
--

DROP ROLE analyst;
DROP ROLE app_user;
DROP ROLE developer;
DROP ROLE postgres;


--
-- Roles
--

CREATE ROLE analyst;
ALTER ROLE analyst WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE app_user;
ALTER ROLE app_user WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE developer;
ALTER ROLE developer WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:HoFJG/uS6uDGNYWiM3qzaw==$Z7iGmVIHAXRh5fJn2XhINNNgYmXY8GPvsdSCX3No+Xk=:LDUhl4xfrupBSDHyezjtnCBFH0/WAgZqk/PuKqeU6fU=';

--
-- User Configurations
--








--
-- Databases
--

--
-- Database "template1" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

UPDATE pg_catalog.pg_database SET datistemplate = false WHERE datname = 'template1';
DROP DATABASE template1;
--
-- Name: template1; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'tr-TR';


ALTER DATABASE template1 OWNER TO postgres;

\connect template1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE template1; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE template1 IS 'default template for new databases';


--
-- Name: template1; Type: DATABASE PROPERTIES; Schema: -; Owner: postgres
--

ALTER DATABASE template1 IS_TEMPLATE = true;


\connect template1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE template1; Type: ACL; Schema: -; Owner: postgres
--

REVOKE CONNECT,TEMPORARY ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


--
-- PostgreSQL database dump complete
--

--
-- Database "open_banking" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: open_banking; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE open_banking WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'tr-TR';


ALTER DATABASE open_banking OWNER TO postgres;

\connect open_banking

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: change_account_balance(integer, numeric, character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.change_account_balance(p_account_id integer, p_amount numeric, p_tx_type character varying, p_description text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_bal NUMERIC;
BEGIN
  -- 1. Kilit al
  SELECT balance
    INTO v_bal
    FROM accounts
   WHERE account_id = p_account_id
     FOR UPDATE;

  -- 2. İş kuralı: çekimse bakiye kontrolü
  IF p_tx_type = 'withdrawal' AND p_amount > v_bal THEN
    RAISE EXCEPTION 'Insufficient funds (have %)', v_bal;
  END IF;

  -- 3. Bakiyeyi güncelle
  IF p_tx_type IN ('deposit','transfer_in') THEN
    UPDATE accounts
       SET balance = balance + p_amount
     WHERE account_id = p_account_id;
  ELSE
    UPDATE accounts
       SET balance = balance - p_amount
     WHERE account_id = p_account_id;
  END IF;

  -- 4. İşlem kaydını ekle
  INSERT INTO transactions (
    account_id, amount, transaction_type, description
  ) VALUES (
    p_account_id, p_amount, p_tx_type, p_description
  );
END;
$$;


ALTER FUNCTION public.change_account_balance(p_account_id integer, p_amount numeric, p_tx_type character varying, p_description text) OWNER TO postgres;

--
-- Name: create_consent_if_not_exists(integer, integer, timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_consent_if_not_exists(p_customer_id integer, p_bank_id integer, p_start timestamp with time zone, p_end timestamp with time zone, p_token text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Tekil (customer_id, bank_id) kontrolü
  IF NOT EXISTS (
    SELECT 1 FROM consents
     WHERE customer_id = p_customer_id
       AND bank_id     = p_bank_id
  ) THEN
    INSERT INTO consents(
      customer_id, bank_id,
      consent_start, consent_end,
      status, token
    ) VALUES (
      p_customer_id, p_bank_id,
      p_start,       p_end,
      'valid',       p_token
    );
  END IF;
END;
$$;


ALTER FUNCTION public.create_consent_if_not_exists(p_customer_id integer, p_bank_id integer, p_start timestamp with time zone, p_end timestamp with time zone, p_token text) OWNER TO postgres;

--
-- Name: fn_audit_transactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_audit_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs(table_name, operation, record_id, changed_data)
      VALUES('transactions','I', NEW.transaction_id, row_to_json(NEW)::jsonb);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_logs(table_name, operation, record_id, changed_data)
      VALUES('transactions','U', NEW.transaction_id,
             jsonb_build_object('old', row_to_json(OLD),
                                'new', row_to_json(NEW)));
    RETURN NEW;
  ELSE  -- DELETE
    INSERT INTO audit_logs(table_name, operation, record_id, changed_data)
      VALUES('transactions','D', OLD.transaction_id, row_to_json(OLD)::jsonb);
    RETURN OLD;
  END IF;
END;
$$;


ALTER FUNCTION public.fn_audit_transactions() OWNER TO postgres;

--
-- Name: fn_cascade_bank_code(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_cascade_bank_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  old_pref TEXT := OLD.bank_code;
  new_pref TEXT := NEW.bank_code;
BEGIN
  UPDATE accounts
    SET account_number = regexp_replace(account_number,
                                        '^'||old_pref, new_pref)
    WHERE bank_id = NEW.bank_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_cascade_bank_code() OWNER TO postgres;

--
-- Name: fn_check_account_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_check_account_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status TEXT;
BEGIN
    ----------------------------------------------------------------
    -- INSERT edildiğinde ilgili hesabın status’ünü kontrol et
    ----------------------------------------------------------------
    SELECT status
      INTO v_status
      FROM public.accounts   -- tablo/şema adınızı koruyun
     WHERE account_id = NEW.account_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Account % does not exist', NEW.account_id;
    END IF;

    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Account % is %; only ACTIVE accounts can receive or send funds',
                        NEW.account_id, v_status;
    END IF;

    RETURN NEW;   -- kontrol geçti, devam et
END;
$$;


ALTER FUNCTION public.fn_check_account_status() OWNER TO postgres;

--
-- Name: fn_check_balance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_check_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cur_bal NUMERIC(15,2);
BEGIN
  SELECT balance INTO cur_bal
    FROM accounts
    WHERE account_id = NEW.account_id
    FOR UPDATE;
  IF NEW.transaction_type = 'withdrawal' AND NEW.amount > cur_bal THEN
    RAISE EXCEPTION 'Insufficient funds (balance: %)', cur_bal;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_check_balance() OWNER TO postgres;

--
-- Name: fn_notify_new_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_notify_new_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM pg_notify(
    'new_transaction',
    json_build_object(
      'tx_id', NEW.transaction_id,
      'acct', NEW.account_id,
      'amount', NEW.amount,
      'type', NEW.transaction_type,
      'at', NEW.transaction_date
    )::text
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_notify_new_transaction() OWNER TO postgres;

--
-- Name: fn_update_balance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_update_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    ----------------------------------------------------------
    -- INSERT
    ----------------------------------------------------------
    IF TG_OP = 'INSERT' THEN
        IF    NEW.transaction_type IN ('deposit', 'transfer_in') THEN
            UPDATE public.accounts
               SET balance = balance + NEW.amount
             WHERE account_id = NEW.account_id;

        ELSIF NEW.transaction_type IN ('withdrawal', 'transfer_out') THEN
            UPDATE public.accounts
               SET balance = balance - NEW.amount
             WHERE account_id = NEW.account_id;
        END IF;

    ----------------------------------------------------------
    -- DELETE  (tersi için, isteğe bağlı)
    ----------------------------------------------------------
    ELSIF TG_OP = 'DELETE' THEN
        IF    OLD.transaction_type IN ('deposit', 'transfer_in') THEN
            UPDATE public.accounts
               SET balance = balance - OLD.amount
             WHERE account_id = OLD.account_id;

        ELSIF OLD.transaction_type IN ('withdrawal', 'transfer_out') THEN
            UPDATE public.accounts
               SET balance = balance + OLD.amount
             WHERE account_id = OLD.account_id;
        END IF;
    END IF;

    RETURN NULL;   -- AFTER-trigger, tabloyu değiştirmiyoruz
END;
$$;


ALTER FUNCTION public.fn_update_balance() OWNER TO postgres;

--
-- Name: get_customer_account_summary(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_customer_account_summary(p_customer_id integer) RETURNS TABLE(account_count integer, total_balance numeric)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(a.account_id),
    COALESCE(SUM(a.balance),0)
  FROM accounts a
  WHERE a.customer_id = p_customer_id;
END;
$$;


ALTER FUNCTION public.get_customer_account_summary(p_customer_id integer) OWNER TO postgres;

--
-- Name: mask_account_number(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.mask_account_number(p_acc_num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT '****' || RIGHT(p_acc_num, 4);
$$;


ALTER FUNCTION public.mask_account_number(p_acc_num text) OWNER TO postgres;

--
-- Name: transfer_funds(integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.transfer_funds(p_from_account integer, p_to_account integer, p_amount numeric) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION 'Source and destination accounts are the same';
    END IF;
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;

    /* yalnızca iki INSERT – bakiyeyi tetikleyici güncelleyecek */
    INSERT INTO public.transactions(account_id, amount, transaction_type, description)
    VALUES
        (p_from_account, p_amount, 'transfer_out',
         format('Transfer to account %s', p_to_account)),
        (p_to_account,   p_amount, 'transfer_in',
         format('Transfer from account %s', p_from_account));
END;
$$;


ALTER FUNCTION public.transfer_funds(p_from_account integer, p_to_account integer, p_amount numeric) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    account_id integer NOT NULL,
    customer_id integer NOT NULL,
    bank_id integer NOT NULL,
    currency character(3) NOT NULL,
    balance numeric(15,2) DEFAULT 0 NOT NULL,
    opened_at date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) NOT NULL,
    CONSTRAINT accounts_currency_check1 CHECK ((currency = ANY (ARRAY['TRY'::bpchar, 'USD'::bpchar, 'EUR'::bpchar]))),
    CONSTRAINT accounts_status_check1 CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- Name: accounts_archive; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts_archive (
    account_id integer NOT NULL,
    account_number character varying(34) NOT NULL,
    customer_id integer NOT NULL,
    bank_id integer NOT NULL,
    account_type character varying(50) NOT NULL,
    currency character(3) NOT NULL,
    balance numeric(15,2) DEFAULT 0 NOT NULL,
    opened_at date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) NOT NULL,
    CONSTRAINT accounts_currency_check CHECK ((currency = ANY (ARRAY['TRY'::bpchar, 'USD'::bpchar, 'EUR'::bpchar]))),
    CONSTRAINT accounts_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.accounts_archive OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accounts_account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accounts_account_id_seq OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_account_id_seq OWNED BY public.accounts_archive.account_id;


--
-- Name: accounts_account_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accounts_account_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accounts_account_id_seq1 OWNER TO postgres;

--
-- Name: accounts_account_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_account_id_seq1 OWNED BY public.accounts.account_id;


--
-- Name: accounts_orig; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.accounts_orig AS
 SELECT account_id,
    customer_id,
    bank_id,
    currency,
    balance,
    opened_at,
    status
   FROM public.accounts;


ALTER VIEW public.accounts_orig OWNER TO postgres;

--
-- Name: checking_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.checking_accounts (
    overdraft_limit numeric(15,2) DEFAULT 0 NOT NULL,
    account_type text DEFAULT 'checking'::text NOT NULL,
    CONSTRAINT chk_checking_type CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
)
INHERITS (public.accounts);


ALTER TABLE public.checking_accounts OWNER TO postgres;

--
-- Name: credit_card_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credit_card_accounts (
    credit_limit numeric(15,2) NOT NULL,
    account_type text DEFAULT 'credit_card'::text NOT NULL,
    CONSTRAINT chk_credit_limit CHECK ((credit_limit >= (0)::numeric))
)
INHERITS (public.accounts);


ALTER TABLE public.credit_card_accounts OWNER TO postgres;

--
-- Name: savings_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.savings_accounts (
    interest_rate numeric(5,2) DEFAULT 0.00 NOT NULL,
    account_type text DEFAULT 'savings'::text NOT NULL,
    CONSTRAINT chk_savings_interest CHECK ((interest_rate >= (0)::numeric))
)
INHERITS (public.accounts);


ALTER TABLE public.savings_accounts OWNER TO postgres;

--
-- Name: all_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.all_accounts AS
 SELECT checking_accounts.account_id,
    checking_accounts.customer_id,
    checking_accounts.bank_id,
    checking_accounts.currency,
    checking_accounts.balance,
    checking_accounts.opened_at,
    checking_accounts.status,
    checking_accounts.overdraft_limit,
    checking_accounts.account_type,
    'checking'::text AS account_subtype
   FROM public.checking_accounts
UNION ALL
 SELECT savings_accounts.account_id,
    savings_accounts.customer_id,
    savings_accounts.bank_id,
    savings_accounts.currency,
    savings_accounts.balance,
    savings_accounts.opened_at,
    savings_accounts.status,
    savings_accounts.interest_rate AS overdraft_limit,
    savings_accounts.account_type,
    'savings'::text AS account_subtype
   FROM public.savings_accounts
UNION ALL
 SELECT credit_card_accounts.account_id,
    credit_card_accounts.customer_id,
    credit_card_accounts.bank_id,
    credit_card_accounts.currency,
    credit_card_accounts.balance,
    credit_card_accounts.opened_at,
    credit_card_accounts.status,
    credit_card_accounts.credit_limit AS overdraft_limit,
    credit_card_accounts.account_type,
    'credit_card'::text AS account_subtype
   FROM public.credit_card_accounts;


ALTER VIEW public.all_accounts OWNER TO postgres;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    log_id integer NOT NULL,
    table_name text NOT NULL,
    operation character(1) NOT NULL,
    record_id integer,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_data jsonb
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_log_id_seq OWNER TO postgres;

--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_log_id_seq OWNED BY public.audit_logs.log_id;


--
-- Name: banks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.banks (
    bank_id integer NOT NULL,
    bank_name character varying(100) NOT NULL,
    bank_code character varying(50) NOT NULL,
    country character varying(100),
    api_url text
);


ALTER TABLE public.banks OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.banks_bank_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.banks_bank_id_seq OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.banks_bank_id_seq OWNED BY public.banks.bank_id;


--
-- Name: consents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.consents (
    consent_id integer NOT NULL,
    customer_id integer NOT NULL,
    bank_id integer NOT NULL,
    consent_start timestamp with time zone NOT NULL,
    consent_end timestamp with time zone NOT NULL,
    status character varying(20) NOT NULL,
    token text NOT NULL,
    CONSTRAINT consents_status_check CHECK (((status)::text = ANY ((ARRAY['valid'::character varying, 'revoked'::character varying])::text[])))
);


ALTER TABLE public.consents OWNER TO postgres;

--
-- Name: consents_consent_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.consents_consent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.consents_consent_id_seq OWNER TO postgres;

--
-- Name: consents_consent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.consents_consent_id_seq OWNED BY public.consents.consent_id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    customer_id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    phone character varying(20),
    password_hash text NOT NULL,
    birth_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_customer_id_seq OWNER TO postgres;

--
-- Name: customers_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_customer_id_seq OWNED BY public.customers.customer_id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactions (
    transaction_id integer NOT NULL,
    account_id integer NOT NULL,
    transaction_date timestamp with time zone DEFAULT now() NOT NULL,
    amount numeric(15,2) NOT NULL,
    transaction_type character varying(50) NOT NULL,
    description text,
    CONSTRAINT transactions_amount_check CHECK ((amount >= (0)::numeric))
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactions_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_transaction_id_seq OWNED BY public.transactions.transaction_id;


--
-- Name: vw_account_transaction_stats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_account_transaction_stats AS
 SELECT account_id,
    count(*) AS tx_count,
    sum(amount) AS tx_total_amount,
    min(transaction_date) AS first_tx,
    max(transaction_date) AS last_tx
   FROM public.transactions t
  GROUP BY account_id;


ALTER VIEW public.vw_account_transaction_stats OWNER TO postgres;

--
-- Name: vw_active_consents; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_active_consents AS
 SELECT consent_id,
    customer_id,
    bank_id,
    consent_start,
    consent_end,
    token
   FROM public.consents c
  WHERE ((status)::text = 'valid'::text);


ALTER VIEW public.vw_active_consents OWNER TO postgres;

--
-- Name: vw_customer_account_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_customer_account_summary AS
 SELECT customer_id,
    count(*) AS account_count,
    sum(balance) AS total_balance
   FROM public.accounts
  GROUP BY customer_id;


ALTER VIEW public.vw_customer_account_summary OWNER TO postgres;

--
-- Name: vw_masked_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_masked_accounts AS
 SELECT account_id,
    concat('****', "right"((account_number)::text, 4)) AS masked_account_number,
    account_type,
    currency,
    balance,
    status
   FROM public.accounts_archive;


ALTER VIEW public.vw_masked_accounts OWNER TO postgres;

--
-- Name: vw_recent_transactions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_recent_transactions AS
 SELECT transaction_id,
    account_id,
    transaction_date,
    amount,
    transaction_type,
    description
   FROM public.transactions t
  WHERE (transaction_date >= (now() - '30 days'::interval));


ALTER VIEW public.vw_recent_transactions OWNER TO postgres;

--
-- Name: accounts account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq1'::regclass);


--
-- Name: accounts_archive account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_archive ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq'::regclass);


--
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- Name: banks bank_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banks ALTER COLUMN bank_id SET DEFAULT nextval('public.banks_bank_id_seq'::regclass);


--
-- Name: checking_accounts account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.checking_accounts ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq1'::regclass);


--
-- Name: checking_accounts balance; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.checking_accounts ALTER COLUMN balance SET DEFAULT 0;


--
-- Name: checking_accounts opened_at; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.checking_accounts ALTER COLUMN opened_at SET DEFAULT CURRENT_DATE;


--
-- Name: consents consent_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents ALTER COLUMN consent_id SET DEFAULT nextval('public.consents_consent_id_seq'::regclass);


--
-- Name: credit_card_accounts account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_card_accounts ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq1'::regclass);


--
-- Name: credit_card_accounts balance; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_card_accounts ALTER COLUMN balance SET DEFAULT 0;


--
-- Name: credit_card_accounts opened_at; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_card_accounts ALTER COLUMN opened_at SET DEFAULT CURRENT_DATE;


--
-- Name: customers customer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN customer_id SET DEFAULT nextval('public.customers_customer_id_seq'::regclass);


--
-- Name: savings_accounts account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts ALTER COLUMN account_id SET DEFAULT nextval('public.accounts_account_id_seq1'::regclass);


--
-- Name: savings_accounts balance; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts ALTER COLUMN balance SET DEFAULT 0;


--
-- Name: savings_accounts opened_at; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts ALTER COLUMN opened_at SET DEFAULT CURRENT_DATE;


--
-- Name: transactions transaction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN transaction_id SET DEFAULT nextval('public.transactions_transaction_id_seq'::regclass);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (account_id, customer_id, bank_id, currency, balance, opened_at, status) FROM stdin;
2	1	2	USD	350.50	2025-06-26	active
3	1	2	TRY	600.00	2025-06-27	closed
1	1	2	TRY	900.00	2025-06-27	active
4	1	1	TRY	1100.00	2025-06-27	active
\.


--
-- Data for Name: accounts_archive; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_archive (account_id, account_number, customer_id, bank_id, account_type, currency, balance, opened_at, status) FROM stdin;
3	TR3000000003	2	1	checking	TRY	750.75	2025-06-26	active
1	TR1000000001	1	1	checking	TRY	1300.00	2025-06-26	active
2	TR2000000002	1	2	savings	USD	250.50	2025-06-26	active
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (log_id, table_name, operation, record_id, changed_at, changed_data) FROM stdin;
1	transactions	I	5	2025-06-26 22:35:59.853642+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to acct 2", "transaction_id": 5, "transaction_date": "2025-06-26T22:35:59.853642+03:00", "transaction_type": "transfer_out"}
2	transactions	I	6	2025-06-26 22:35:59.853642+03	{"amount": 100.00, "account_id": 2, "description": "Transfer from acct 1", "transaction_id": 6, "transaction_date": "2025-06-26T22:35:59.853642+03:00", "transaction_type": "transfer_in"}
3	transactions	I	7	2025-06-27 07:11:23.874523+03	{"amount": 100.00, "account_id": 1, "description": "Test deposit", "transaction_id": 7, "transaction_date": "2025-06-24T07:11:23.874523+03:00", "transaction_type": "deposit"}
4	transactions	I	8	2025-06-27 07:11:23.874523+03	{"amount": 25.00, "account_id": 1, "description": "Test withdrawal", "transaction_id": 8, "transaction_date": "2025-06-25T07:11:23.874523+03:00", "transaction_type": "withdrawal"}
5	transactions	I	9	2025-06-27 07:11:23.874523+03	{"amount": 50.00, "account_id": 1, "description": "Test deposit 2", "transaction_id": 9, "transaction_date": "2025-06-26T07:11:23.874523+03:00", "transaction_type": "deposit"}
6	transactions	I	10	2025-06-27 07:11:23.874523+03	{"amount": 200.00, "account_id": 2, "description": "Test deposit", "transaction_id": 10, "transaction_date": "2025-06-23T07:11:23.874523+03:00", "transaction_type": "deposit"}
7	transactions	I	11	2025-06-27 07:11:23.874523+03	{"amount": 75.50, "account_id": 2, "description": "Test withdrawal", "transaction_id": 11, "transaction_date": "2025-06-27T05:11:23.874523+03:00", "transaction_type": "withdrawal"}
8	transactions	I	14	2025-06-27 07:15:04.358879+03	{"amount": 100.00, "account_id": 1, "description": "Initial test deposit", "transaction_id": 14, "transaction_date": "2025-06-27T07:15:04.358879+03:00", "transaction_type": "deposit"}
9	transactions	I	15	2025-06-27 07:15:04.358879+03	{"amount": 30.00, "account_id": 1, "description": "Test withdrawal", "transaction_id": 15, "transaction_date": "2025-06-27T07:15:04.358879+03:00", "transaction_type": "withdrawal"}
10	transactions	D	15	2025-06-27 09:57:07.844874+03	{"amount": 30.00, "account_id": 1, "description": "Test withdrawal", "transaction_id": 15, "transaction_date": "2025-06-27T07:15:04.358879+03:00", "transaction_type": "withdrawal"}
11	transactions	D	14	2025-06-27 09:57:08.907558+03	{"amount": 100.00, "account_id": 1, "description": "Initial test deposit", "transaction_id": 14, "transaction_date": "2025-06-27T07:15:04.358879+03:00", "transaction_type": "deposit"}
12	transactions	D	5	2025-06-27 09:57:09.632403+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to acct 2", "transaction_id": 5, "transaction_date": "2025-06-26T22:35:59.853642+03:00", "transaction_type": "transfer_out"}
13	transactions	D	9	2025-06-27 09:57:10.341897+03	{"amount": 50.00, "account_id": 1, "description": "Test deposit 2", "transaction_id": 9, "transaction_date": "2025-06-26T07:11:23.874523+03:00", "transaction_type": "deposit"}
14	transactions	U	8	2025-06-27 09:57:12.727057+03	{"new": {"amount": 25.00, "account_id": 1, "description": "Test withdrawal", "transaction_id": 8, "transaction_date": "2025-06-25T04:11:23.874523+03:00", "transaction_type": "withdrawal"}, "old": {"amount": 25.00, "account_id": 1, "description": "Test withdrawal", "transaction_id": 8, "transaction_date": "2025-06-25T07:11:23.874523+03:00", "transaction_type": "withdrawal"}}
15	transactions	I	16	2025-06-27 10:33:41.044406+03	{"amount": 123.00, "account_id": 1, "description": "Transfer to acct 1", "transaction_id": 16, "transaction_date": "2025-06-27T10:33:41.044406+03:00", "transaction_type": "transfer_out"}
16	transactions	I	17	2025-06-27 10:33:41.044406+03	{"amount": 123.00, "account_id": 1, "description": "Transfer from acct 1", "transaction_id": 17, "transaction_date": "2025-06-27T10:33:41.044406+03:00", "transaction_type": "transfer_in"}
17	transactions	I	20	2025-06-27 11:37:24.851644+03	{"amount": 500.00, "account_id": 1, "description": "Transfer to acct 3", "transaction_id": 20, "transaction_date": "2025-06-27T11:37:24.851644+03:00", "transaction_type": "transfer_out"}
18	transactions	I	21	2025-06-27 11:37:24.851644+03	{"amount": 500.00, "account_id": 3, "description": "Transfer from acct 1", "transaction_id": 21, "transaction_date": "2025-06-27T11:37:24.851644+03:00", "transaction_type": "transfer_in"}
19	transactions	I	22	2025-06-27 11:37:25.784208+03	{"amount": 500.00, "account_id": 1, "description": "Transfer to acct 3", "transaction_id": 22, "transaction_date": "2025-06-27T11:37:25.784208+03:00", "transaction_type": "transfer_out"}
20	transactions	I	23	2025-06-27 11:37:25.784208+03	{"amount": 500.00, "account_id": 3, "description": "Transfer from acct 1", "transaction_id": 23, "transaction_date": "2025-06-27T11:37:25.784208+03:00", "transaction_type": "transfer_in"}
21	transactions	I	24	2025-06-27 11:39:02.421705+03	{"amount": 500.00, "account_id": 1, "description": "Transfer to acct 3", "transaction_id": 24, "transaction_date": "2025-06-27T11:39:02.421705+03:00", "transaction_type": "transfer_out"}
22	transactions	I	25	2025-06-27 11:39:02.421705+03	{"amount": 500.00, "account_id": 3, "description": "Transfer from acct 1", "transaction_id": 25, "transaction_date": "2025-06-27T11:39:02.421705+03:00", "transaction_type": "transfer_in"}
25	transactions	I	31	2025-06-27 12:00:29.529522+03	{"amount": 111.00, "account_id": 1, "description": "Transfer to acct 2", "transaction_id": 31, "transaction_date": "2025-06-27T12:00:29.529522+03:00", "transaction_type": "transfer_out"}
26	transactions	I	32	2025-06-27 12:00:29.529522+03	{"amount": 111.00, "account_id": 2, "description": "Transfer from acct 1", "transaction_id": 32, "transaction_date": "2025-06-27T12:00:29.529522+03:00", "transaction_type": "transfer_in"}
27	transactions	I	33	2025-06-27 12:01:01.687742+03	{"amount": 111.00, "account_id": 1, "description": "Transfer to acct 4", "transaction_id": 33, "transaction_date": "2025-06-27T12:01:01.687742+03:00", "transaction_type": "transfer_out"}
28	transactions	I	34	2025-06-27 12:01:01.687742+03	{"amount": 111.00, "account_id": 4, "description": "Transfer from acct 1", "transaction_id": 34, "transaction_date": "2025-06-27T12:01:01.687742+03:00", "transaction_type": "transfer_in"}
29	transactions	I	35	2025-06-27 12:01:55.600185+03	{"amount": 10.00, "account_id": 1, "description": "Transfer to acct 4", "transaction_id": 35, "transaction_date": "2025-06-27T12:01:55.600185+03:00", "transaction_type": "transfer_out"}
30	transactions	I	36	2025-06-27 12:01:55.600185+03	{"amount": 10.00, "account_id": 4, "description": "Transfer from acct 1", "transaction_id": 36, "transaction_date": "2025-06-27T12:01:55.600185+03:00", "transaction_type": "transfer_in"}
33	transactions	I	39	2025-06-27 12:08:46.408084+03	{"amount": 10.00, "account_id": 1, "description": "Transfer to acct 4", "transaction_id": 39, "transaction_date": "2025-06-27T12:08:46.408084+03:00", "transaction_type": "transfer_out"}
34	transactions	I	40	2025-06-27 12:08:46.408084+03	{"amount": 10.00, "account_id": 4, "description": "Transfer from acct 1", "transaction_id": 40, "transaction_date": "2025-06-27T12:08:46.408084+03:00", "transaction_type": "transfer_in"}
35	transactions	I	41	2025-06-27 12:09:06.169604+03	{"amount": 5.00, "account_id": 1, "description": "Transfer to acct 4", "transaction_id": 41, "transaction_date": "2025-06-27T12:09:06.169604+03:00", "transaction_type": "transfer_out"}
36	transactions	I	42	2025-06-27 12:09:06.169604+03	{"amount": 5.00, "account_id": 4, "description": "Transfer from acct 1", "transaction_id": 42, "transaction_date": "2025-06-27T12:09:06.169604+03:00", "transaction_type": "transfer_in"}
37	transactions	I	43	2025-06-27 12:11:12.839695+03	{"amount": 1.00, "account_id": 1, "description": "Transfer to account 4", "transaction_id": 43, "transaction_date": "2025-06-27T12:11:12.839695+03:00", "transaction_type": "transfer_out"}
38	transactions	I	44	2025-06-27 12:11:12.839695+03	{"amount": 1.00, "account_id": 4, "description": "Transfer from account 1", "transaction_id": 44, "transaction_date": "2025-06-27T12:11:12.839695+03:00", "transaction_type": "transfer_in"}
39	transactions	I	45	2025-06-27 12:13:33.645873+03	{"amount": 10.00, "account_id": 4, "description": "Transfer to account 1", "transaction_id": 45, "transaction_date": "2025-06-27T12:13:33.645873+03:00", "transaction_type": "transfer_out"}
40	transactions	I	46	2025-06-27 12:13:33.645873+03	{"amount": 10.00, "account_id": 1, "description": "Transfer from account 4", "transaction_id": 46, "transaction_date": "2025-06-27T12:13:33.645873+03:00", "transaction_type": "transfer_in"}
43	transactions	I	49	2025-06-27 12:17:39.43863+03	{"amount": 10.00, "account_id": 4, "description": "Transfer to account 1", "transaction_id": 49, "transaction_date": "2025-06-27T12:17:39.43863+03:00", "transaction_type": "transfer_out"}
44	transactions	I	50	2025-06-27 12:17:39.43863+03	{"amount": 10.00, "account_id": 1, "description": "Transfer from account 4", "transaction_id": 50, "transaction_date": "2025-06-27T12:17:39.43863+03:00", "transaction_type": "transfer_in"}
45	transactions	I	51	2025-06-27 12:19:22.15771+03	{"amount": 150.00, "account_id": 4, "description": "Transfer to account 1", "transaction_id": 51, "transaction_date": "2025-06-27T12:19:22.15771+03:00", "transaction_type": "transfer_out"}
46	transactions	I	52	2025-06-27 12:19:22.15771+03	{"amount": 150.00, "account_id": 1, "description": "Transfer from account 4", "transaction_id": 52, "transaction_date": "2025-06-27T12:19:22.15771+03:00", "transaction_type": "transfer_in"}
47	transactions	I	53	2025-06-27 12:19:51.261188+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to account 2", "transaction_id": 53, "transaction_date": "2025-06-27T12:19:51.261188+03:00", "transaction_type": "transfer_out"}
48	transactions	I	54	2025-06-27 12:19:51.261188+03	{"amount": 100.00, "account_id": 2, "description": "Transfer from account 1", "transaction_id": 54, "transaction_date": "2025-06-27T12:19:51.261188+03:00", "transaction_type": "transfer_in"}
49	transactions	I	55	2025-06-27 12:19:55.416997+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to account 3", "transaction_id": 55, "transaction_date": "2025-06-27T12:19:55.416997+03:00", "transaction_type": "transfer_out"}
50	transactions	I	56	2025-06-27 12:19:55.416997+03	{"amount": 100.00, "account_id": 3, "description": "Transfer from account 1", "transaction_id": 56, "transaction_date": "2025-06-27T12:19:55.416997+03:00", "transaction_type": "transfer_in"}
51	transactions	I	59	2025-06-27 12:23:27.004228+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to account 4", "transaction_id": 59, "transaction_date": "2025-06-27T12:23:27.004228+03:00", "transaction_type": "transfer_out"}
52	transactions	I	60	2025-06-27 12:23:27.004228+03	{"amount": 100.00, "account_id": 4, "description": "Transfer from account 1", "transaction_id": 60, "transaction_date": "2025-06-27T12:23:27.004228+03:00", "transaction_type": "transfer_in"}
53	transactions	I	63	2025-06-27 12:33:59.120504+03	{"amount": 100.00, "account_id": 1, "description": "Transfer to account 4", "transaction_id": 63, "transaction_date": "2025-06-27T12:33:59.120504+03:00", "transaction_type": "transfer_out"}
54	transactions	I	64	2025-06-27 12:33:59.120504+03	{"amount": 100.00, "account_id": 4, "description": "Transfer from account 1", "transaction_id": 64, "transaction_date": "2025-06-27T12:33:59.120504+03:00", "transaction_type": "transfer_in"}
\.


--
-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.banks (bank_id, bank_name, bank_code, country, api_url) FROM stdin;
1	ABC Bank	ABC_TR	Turkey	https://api.abc.com/openbanking
2	XYZ Bank	XYZ_UK	UK	https://api.xyz.co.uk/openbanking
\.


--
-- Data for Name: checking_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.checking_accounts (account_id, customer_id, bank_id, currency, balance, opened_at, status, overdraft_limit, account_type) FROM stdin;
\.


--
-- Data for Name: consents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.consents (consent_id, customer_id, bank_id, consent_start, consent_end, status, token) FROM stdin;
3	2	1	2025-06-26 22:23:59.424626+03	2025-09-24 22:23:59.424626+03	valid	tok_abc_2
9	1	2	2025-06-26 15:00:00+03	2025-07-26 15:00:00+03	revoked	token_xyz3
1	1	1	2025-06-26 03:00:00+03	2025-07-26 03:00:00+03	valid	token_abc
\.


--
-- Data for Name: credit_card_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.credit_card_accounts (account_id, customer_id, bank_id, currency, balance, opened_at, status, credit_limit, account_type) FROM stdin;
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (customer_id, full_name, email, phone, password_hash, birth_date, created_at) FROM stdin;
2	Elif Demir	elif@example.com	+90-533-7654321	123	1990-12-02	2025-06-26 22:23:59.424626+03
1	Ahmet Yılmaz	ahmet	+90-555-1234567	123	1985-06-15	2025-06-26 22:23:59.424626+03
\.


--
-- Data for Name: savings_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.savings_accounts (account_id, customer_id, bank_id, currency, balance, opened_at, status, interest_rate, account_type) FROM stdin;
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (transaction_id, account_id, transaction_date, amount, transaction_type, description) FROM stdin;
1	1	2025-06-21 22:23:59.424626+03	500.00	deposit	Salary
2	1	2025-06-24 22:23:59.424626+03	100.00	withdrawal	ATM withdrawal
3	2	2025-06-25 22:23:59.424626+03	50.00	payment	Electricity bill
4	3	2025-06-23 22:23:59.424626+03	200.00	deposit	Transfer from friend
6	2	2025-06-26 22:35:59.853642+03	100.00	transfer_in	Transfer from acct 1
7	1	2025-06-24 07:11:23.874523+03	100.00	deposit	Test deposit
10	2	2025-06-23 07:11:23.874523+03	200.00	deposit	Test deposit
11	2	2025-06-27 05:11:23.874523+03	75.50	withdrawal	Test withdrawal
8	1	2025-06-25 04:11:23.874523+03	25.00	withdrawal	Test withdrawal
16	1	2025-06-27 10:33:41.044406+03	123.00	transfer_out	Transfer to acct 1
17	1	2025-06-27 10:33:41.044406+03	123.00	transfer_in	Transfer from acct 1
20	1	2025-06-27 11:37:24.851644+03	500.00	transfer_out	Transfer to acct 3
21	3	2025-06-27 11:37:24.851644+03	500.00	transfer_in	Transfer from acct 1
22	1	2025-06-27 11:37:25.784208+03	500.00	transfer_out	Transfer to acct 3
23	3	2025-06-27 11:37:25.784208+03	500.00	transfer_in	Transfer from acct 1
24	1	2025-06-27 11:39:02.421705+03	500.00	transfer_out	Transfer to acct 3
25	3	2025-06-27 11:39:02.421705+03	500.00	transfer_in	Transfer from acct 1
31	1	2025-06-27 12:00:29.529522+03	111.00	transfer_out	Transfer to acct 2
32	2	2025-06-27 12:00:29.529522+03	111.00	transfer_in	Transfer from acct 1
33	1	2025-06-27 12:01:01.687742+03	111.00	transfer_out	Transfer to acct 4
34	4	2025-06-27 12:01:01.687742+03	111.00	transfer_in	Transfer from acct 1
35	1	2025-06-27 12:01:55.600185+03	10.00	transfer_out	Transfer to acct 4
36	4	2025-06-27 12:01:55.600185+03	10.00	transfer_in	Transfer from acct 1
39	1	2025-06-27 12:08:46.408084+03	10.00	transfer_out	Transfer to acct 4
40	4	2025-06-27 12:08:46.408084+03	10.00	transfer_in	Transfer from acct 1
41	1	2025-06-27 12:09:06.169604+03	5.00	transfer_out	Transfer to acct 4
42	4	2025-06-27 12:09:06.169604+03	5.00	transfer_in	Transfer from acct 1
43	1	2025-06-27 12:11:12.839695+03	1.00	transfer_out	Transfer to account 4
44	4	2025-06-27 12:11:12.839695+03	1.00	transfer_in	Transfer from account 1
45	4	2025-06-27 12:13:33.645873+03	10.00	transfer_out	Transfer to account 1
46	1	2025-06-27 12:13:33.645873+03	10.00	transfer_in	Transfer from account 4
49	4	2025-06-27 12:17:39.43863+03	10.00	transfer_out	Transfer to account 1
50	1	2025-06-27 12:17:39.43863+03	10.00	transfer_in	Transfer from account 4
51	4	2025-06-27 12:19:22.15771+03	150.00	transfer_out	Transfer to account 1
52	1	2025-06-27 12:19:22.15771+03	150.00	transfer_in	Transfer from account 4
53	1	2025-06-27 12:19:51.261188+03	100.00	transfer_out	Transfer to account 2
54	2	2025-06-27 12:19:51.261188+03	100.00	transfer_in	Transfer from account 1
55	1	2025-06-27 12:19:55.416997+03	100.00	transfer_out	Transfer to account 3
56	3	2025-06-27 12:19:55.416997+03	100.00	transfer_in	Transfer from account 1
59	1	2025-06-27 12:23:27.004228+03	100.00	transfer_out	Transfer to account 4
60	4	2025-06-27 12:23:27.004228+03	100.00	transfer_in	Transfer from account 1
63	1	2025-06-27 12:33:59.120504+03	100.00	transfer_out	Transfer to account 4
64	4	2025-06-27 12:33:59.120504+03	100.00	transfer_in	Transfer from account 1
\.


--
-- Name: accounts_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_account_id_seq', 3, true);


--
-- Name: accounts_account_id_seq1; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_account_id_seq1', 4, true);


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 54, true);


--
-- Name: banks_bank_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.banks_bank_id_seq', 2, true);


--
-- Name: consents_consent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.consents_consent_id_seq', 16, true);


--
-- Name: customers_customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_customer_id_seq', 2, true);


--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_transaction_id_seq', 64, true);


--
-- Name: accounts_archive accounts_bank_id_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_archive
    ADD CONSTRAINT accounts_bank_id_account_number_key UNIQUE (bank_id, account_number);


--
-- Name: accounts_archive accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_archive
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_id);


--
-- Name: accounts accounts_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey1 PRIMARY KEY (account_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- Name: banks banks_bank_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banks
    ADD CONSTRAINT banks_bank_code_key UNIQUE (bank_code);


--
-- Name: banks banks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (bank_id);


--
-- Name: consents consents_customer_id_bank_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_customer_id_bank_id_key UNIQUE (customer_id, bank_id);


--
-- Name: consents consents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_pkey PRIMARY KEY (consent_id);


--
-- Name: customers customers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_email_key UNIQUE (email);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: idx_accounts_bank_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_bank_id ON public.accounts_archive USING btree (bank_id);


--
-- Name: idx_accounts_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_customer_id ON public.accounts_archive USING btree (customer_id);


--
-- Name: idx_consents_bank_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_consents_bank_id ON public.consents USING btree (bank_id);


--
-- Name: idx_consents_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_consents_customer_id ON public.consents USING btree (customer_id);


--
-- Name: idx_transactions_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_account_id ON public.transactions USING btree (account_id);


--
-- Name: idx_transactions_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_date ON public.transactions USING btree (transaction_date);


--
-- Name: transactions trg_audit_transactions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_audit_transactions AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_audit_transactions();


--
-- Name: banks trg_cascade_bank_code; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_cascade_bank_code AFTER UPDATE OF bank_code ON public.banks FOR EACH ROW EXECUTE FUNCTION public.fn_cascade_bank_code();


--
-- Name: transactions trg_check_account_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_account_status BEFORE INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_check_account_status();


--
-- Name: transactions trg_check_balance; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_balance BEFORE INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_check_balance();


--
-- Name: transactions trg_notify_new_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_notify_new_transaction AFTER INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_notify_new_transaction();


--
-- Name: transactions trg_update_balance; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_balance AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_update_balance();


--
-- Name: accounts_archive accounts_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_archive
    ADD CONSTRAINT accounts_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.banks(bank_id) ON DELETE RESTRICT;


--
-- Name: accounts accounts_bank_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_bank_id_fkey1 FOREIGN KEY (bank_id) REFERENCES public.banks(bank_id) ON DELETE RESTRICT;


--
-- Name: accounts_archive accounts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_archive
    ADD CONSTRAINT accounts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id) ON DELETE CASCADE;


--
-- Name: accounts accounts_customer_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_customer_id_fkey1 FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id) ON DELETE CASCADE;


--
-- Name: consents consents_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.banks(bank_id) ON DELETE CASCADE;


--
-- Name: consents consents_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id) ON DELETE CASCADE;


--
-- Name: transactions transactions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(account_id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO analyst;
GRANT USAGE ON SCHEMA public TO app_user;


--
-- Name: TABLE accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.accounts TO developer;
GRANT SELECT ON TABLE public.accounts TO analyst;
GRANT SELECT ON TABLE public.accounts TO app_user;


--
-- Name: TABLE accounts_archive; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.accounts_archive TO developer;
GRANT SELECT ON TABLE public.accounts_archive TO analyst;


--
-- Name: COLUMN accounts_archive.account_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(account_id) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.account_number; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(account_number) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.customer_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(customer_id) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.bank_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(bank_id) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.account_type; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(account_type) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.currency; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(currency) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.balance; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(balance) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.opened_at; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(opened_at) ON TABLE public.accounts_archive TO app_user;


--
-- Name: COLUMN accounts_archive.status; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(status) ON TABLE public.accounts_archive TO app_user;


--
-- Name: SEQUENCE accounts_account_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.accounts_account_id_seq TO developer;


--
-- Name: TABLE accounts_orig; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.accounts_orig TO developer;
GRANT SELECT ON TABLE public.accounts_orig TO analyst;
GRANT SELECT ON TABLE public.accounts_orig TO app_user;


--
-- Name: TABLE checking_accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.checking_accounts TO developer;
GRANT SELECT ON TABLE public.checking_accounts TO analyst;
GRANT SELECT ON TABLE public.checking_accounts TO app_user;


--
-- Name: TABLE credit_card_accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.credit_card_accounts TO developer;
GRANT SELECT ON TABLE public.credit_card_accounts TO analyst;
GRANT SELECT ON TABLE public.credit_card_accounts TO app_user;


--
-- Name: TABLE savings_accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.savings_accounts TO developer;
GRANT SELECT ON TABLE public.savings_accounts TO analyst;
GRANT SELECT ON TABLE public.savings_accounts TO app_user;


--
-- Name: TABLE all_accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.all_accounts TO developer;
GRANT SELECT ON TABLE public.all_accounts TO analyst;
GRANT SELECT ON TABLE public.all_accounts TO app_user;


--
-- Name: TABLE audit_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.audit_logs TO developer;
GRANT SELECT ON TABLE public.audit_logs TO analyst;
GRANT SELECT ON TABLE public.audit_logs TO app_user;


--
-- Name: TABLE banks; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.banks TO developer;
GRANT SELECT ON TABLE public.banks TO analyst;


--
-- Name: SEQUENCE banks_bank_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.banks_bank_id_seq TO developer;


--
-- Name: TABLE consents; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.consents TO developer;
GRANT SELECT ON TABLE public.consents TO analyst;


--
-- Name: SEQUENCE consents_consent_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.consents_consent_id_seq TO developer;


--
-- Name: TABLE customers; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.customers TO developer;
GRANT SELECT ON TABLE public.customers TO analyst;


--
-- Name: SEQUENCE customers_customer_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.customers_customer_id_seq TO developer;


--
-- Name: TABLE transactions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.transactions TO developer;
GRANT SELECT ON TABLE public.transactions TO analyst;


--
-- Name: COLUMN transactions.transaction_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(transaction_id) ON TABLE public.transactions TO app_user;


--
-- Name: COLUMN transactions.account_id; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(account_id) ON TABLE public.transactions TO app_user;


--
-- Name: COLUMN transactions.transaction_date; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(transaction_date) ON TABLE public.transactions TO app_user;


--
-- Name: COLUMN transactions.amount; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(amount) ON TABLE public.transactions TO app_user;


--
-- Name: COLUMN transactions.transaction_type; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(transaction_type) ON TABLE public.transactions TO app_user;


--
-- Name: COLUMN transactions.description; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT(description) ON TABLE public.transactions TO app_user;


--
-- Name: SEQUENCE transactions_transaction_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.transactions_transaction_id_seq TO developer;


--
-- Name: TABLE vw_account_transaction_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_account_transaction_stats TO developer;
GRANT SELECT ON TABLE public.vw_account_transaction_stats TO analyst;
GRANT SELECT ON TABLE public.vw_account_transaction_stats TO app_user;


--
-- Name: TABLE vw_active_consents; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_active_consents TO developer;
GRANT SELECT ON TABLE public.vw_active_consents TO analyst;
GRANT SELECT ON TABLE public.vw_active_consents TO app_user;


--
-- Name: TABLE vw_customer_account_summary; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_customer_account_summary TO developer;
GRANT SELECT ON TABLE public.vw_customer_account_summary TO analyst;
GRANT SELECT ON TABLE public.vw_customer_account_summary TO app_user;


--
-- Name: TABLE vw_masked_accounts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_masked_accounts TO developer;
GRANT SELECT ON TABLE public.vw_masked_accounts TO analyst;
GRANT SELECT ON TABLE public.vw_masked_accounts TO app_user;


--
-- Name: TABLE vw_recent_transactions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_recent_transactions TO developer;
GRANT SELECT ON TABLE public.vw_recent_transactions TO analyst;
GRANT SELECT ON TABLE public.vw_recent_transactions TO app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO developer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO analyst;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO app_user;


--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE postgres;
--
-- Name: postgres; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'tr-TR';


ALTER DATABASE postgres OWNER TO postgres;

\connect postgres

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

