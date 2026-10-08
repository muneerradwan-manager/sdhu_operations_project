-- Enums for the Hajj Operations domain
create type account_status_enum as enum ('incomplete', 'pending', 'approved', 'rejected');
create type gender_enum as enum ('male', 'female');
create type mission_type_enum as enum ('administrative', 'religious', 'medical');
create type participation_status_enum as enum ('active', 'withdrawn');
