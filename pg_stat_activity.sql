-- run this SQL as a super user, then all users can see all query details in pg_stat_activity

CREATE OR REPLACE FUNCTION public.pg_stat_activity() RETURNS SETOF pg_catalog.pg_stat_activity
AS $BODY$
DECLARE
 rec RECORD;
BEGIN
    -- Author: Tony Wasson (part of nagiosplugins for postgresql)
    -- Overview: Let non super users see query details from pg_stat_activity
    -- Revisions: (when, who, what)
    --   2006-08-29 TW - Checked into CVS after a user request.
    FOR rec IN SELECT * FROM pg_stat_activity
    LOOP
        RETURN NEXT rec;
    END LOOP;
    RETURN;
END;
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;

