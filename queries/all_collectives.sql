SELECT "public"."Collectives"."id" AS "id", 
"public"."Collectives"."name" AS "name", 
"public"."Collectives"."countryISO" AS "countryISO", 
"public"."Collectives"."currency" AS "currency", 
"public"."Collectives"."description" AS "description", 
"public"."Collectives"."geoLocationLatLong" AS "geoLocationLatLong", 
"public"."Collectives"."HostCollectiveId" AS "HostCollectiveId", 
"public"."Collectives"."hostFeePercent" AS "hostFeePercent", 
"public"."Collectives"."isHostAccount" AS "isHostAccount", 
"public"."Collectives"."longDescription" AS "longDescription", 
"public"."Collectives"."ParentCollectiveId" AS "ParentCollectiveId", 
"public"."Collectives"."platformFeePercent" AS "platformFeePercent", 
"public"."Collectives"."slug" AS "slug", "public"."Collectives"."type" AS "type"
FROM "public"."Collectives"
