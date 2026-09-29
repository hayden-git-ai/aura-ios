-- A support message is persisted before it is relayed to Crisp. Track that
-- second step so a client retry can safely finish delivery without inserting a
-- duplicate row. New clients use their local message UUID as the row id.

alter table public.support_messages
    add column if not exists crisp_relayed_at timestamptz;
