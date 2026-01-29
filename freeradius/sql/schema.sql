--
-- PostgreSQL schema for FreeRADIUS with NAS-Identifier support
-- Extended from default FreeRADIUS schema
--

-- Accounting table with nasidentifier column
CREATE TABLE IF NOT EXISTS radacct (
    radacctid           bigserial PRIMARY KEY,
    acctsessionid       text NOT NULL,
    acctuniqueid        text NOT NULL UNIQUE,
    username            text,
    realm               text,
    nasipaddress        inet NOT NULL,
    nasidentifier       text DEFAULT '',
    nasportid           text,
    nasporttype         text,
    acctstarttime       timestamp with time zone,
    acctupdatetime      timestamp with time zone,
    acctstoptime        timestamp with time zone,
    acctinterval        bigint,
    acctsessiontime     bigint,
    acctauthentic       text,
    connectinfo_start   text,
    connectinfo_stop    text,
    acctinputoctets     bigint,
    acctoutputoctets    bigint,
    calledstationid     text,
    callingstationid    text,
    acctterminatecause  text,
    servicetype         text,
    framedprotocol      text,
    framedipaddress     inet,
    framedipv6address   inet,
    framedipv6prefix    inet,
    framedinterfaceid   text,
    delegatedipv6prefix inet,
    class               text
);

CREATE INDEX radacct_active_session_idx ON radacct (acctuniqueid) WHERE acctstoptime IS NULL;
CREATE INDEX radacct_bulk_close ON radacct (nasipaddress, acctstarttime) WHERE acctstoptime IS NULL;
CREATE INDEX radacct_start_user_idx ON radacct (acctstarttime, username);
CREATE INDEX radacct_nasidentifier_idx ON radacct (nasidentifier);
CREATE INDEX radacct_class_idx ON radacct (class);

-- Post-auth table with NAS info columns
CREATE TABLE IF NOT EXISTS radpostauth (
    id                  bigserial PRIMARY KEY,
    username            text NOT NULL,
    pass                text,
    reply               text,
    nasipaddress        text DEFAULT '',
    nasidentifier       text DEFAULT '',
    calledstationid     text DEFAULT '',
    callingstationid    text DEFAULT '',
    authdate            timestamp with time zone NOT NULL DEFAULT now(),
    class               text
);

CREATE INDEX radpostauth_username_idx ON radpostauth (username);
CREATE INDEX radpostauth_nasidentifier_idx ON radpostauth (nasidentifier);
CREATE INDEX radpostauth_authdate_idx ON radpostauth (authdate);
CREATE INDEX radpostauth_class_idx ON radpostauth (class);

-- User check attributes (passwords)
CREATE TABLE IF NOT EXISTS radcheck (
    id          serial PRIMARY KEY,
    username    text NOT NULL DEFAULT '',
    attribute   text NOT NULL DEFAULT '',
    op          char(2) NOT NULL DEFAULT ':=',
    value       text NOT NULL DEFAULT ''
);
CREATE INDEX radcheck_username_idx ON radcheck (username);

-- User reply attributes
CREATE TABLE IF NOT EXISTS radreply (
    id          serial PRIMARY KEY,
    username    text NOT NULL DEFAULT '',
    attribute   text NOT NULL DEFAULT '',
    op          char(2) NOT NULL DEFAULT '=',
    value       text NOT NULL DEFAULT ''
);
CREATE INDEX radreply_username_idx ON radreply (username);

-- User group membership
CREATE TABLE IF NOT EXISTS radusergroup (
    id          serial PRIMARY KEY,
    username    text NOT NULL DEFAULT '',
    groupname   text NOT NULL DEFAULT '',
    priority    integer NOT NULL DEFAULT 1
);
CREATE INDEX radusergroup_username_idx ON radusergroup (username);

-- Group check attributes
CREATE TABLE IF NOT EXISTS radgroupcheck (
    id          serial PRIMARY KEY,
    groupname   text NOT NULL DEFAULT '',
    attribute   text NOT NULL DEFAULT '',
    op          char(2) NOT NULL DEFAULT ':=',
    value       text NOT NULL DEFAULT ''
);
CREATE INDEX radgroupcheck_groupname_idx ON radgroupcheck (groupname);

-- Group reply attributes
CREATE TABLE IF NOT EXISTS radgroupreply (
    id          serial PRIMARY KEY,
    groupname   text NOT NULL DEFAULT '',
    attribute   text NOT NULL DEFAULT '',
    op          char(2) NOT NULL DEFAULT '=',
    value       text NOT NULL DEFAULT ''
);
CREATE INDEX radgroupreply_groupname_idx ON radgroupreply (groupname);
