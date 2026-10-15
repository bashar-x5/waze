DROP TABLE IF EXISTS "Users";

CREATE TABLE "Users" (
    "UserId" VARCHAR(64) PRIMARY KEY,
    "FirstSeenAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "LastSeenAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "ReportCount" INT NOT NULL DEFAULT 0,
    "ConfirmationCount" INT NOT NULL DEFAULT 0,
    "Status" VARCHAR(32) NOT NULL DEFAULT 'active',
    "LastLatitude" DOUBLE PRECISION,
    "LastLongitude" DOUBLE PRECISION,
    "LastSpeedKmh" DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS "IX_Users_LastSeenAt" ON "Users" ("LastSeenAt");
CREATE INDEX IF NOT EXISTS "IX_Users_Status" ON "Users" ("Status");

CREATE TABLE IF NOT EXISTS "IncidentConfirmations" (
    "Id" SERIAL PRIMARY KEY,
    "IncidentId" VARCHAR(64) NOT NULL,
    "UserId" VARCHAR(64) NOT NULL,
    "ConfirmedAt" TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS "IX_IncidentConfirmations_IncidentId_UserId" ON "IncidentConfirmations" ("IncidentId", "UserId");

ALTER TABLE "TrafficIncidents" ADD COLUMN IF NOT EXISTS "UserId" VARCHAR(64);
ALTER TABLE "TrafficIncidents" ADD COLUMN IF NOT EXISTS "IsRoadWarning" BOOLEAN NOT NULL DEFAULT FALSE;
