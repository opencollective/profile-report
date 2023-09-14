SELECT 
    COALESCE("Collectives"."ParentCollectiveId", "Transactions"."CollectiveId") AS "CollectiveId",
    "Transactions"."HostCollectiveId" AS "HostCollectiveId",
    "Transactions"."currency" AS "currency",
    COUNT("Transactions"."id") AS "transactionCount",
    SUM("Transactions"."amount") AS "totalAmount"
FROM 
    "public"."Transactions" AS "Transactions"
LEFT JOIN "public"."Collectives" AS "Collectives"
ON "Transactions"."CollectiveId" = "Collectives"."id"
WHERE 
    "Transactions"."createdAt" >= DATE_TRUNC('month', NOW() - INTERVAL '12 month')
    AND "Transactions"."createdAt" < DATE_TRUNC('month', NOW())
    AND "Transactions"."type" = 'DEBIT'
    AND "Transactions"."kind" = 'EXPENSE'
    AND "Collectives"."type" IN ('COLLECTIVE', 'EVENT', 'FUND', 'PROJECT')
GROUP BY
    COALESCE("Collectives"."ParentCollectiveId", "Transactions"."CollectiveId"),
    "Transactions"."HostCollectiveId",
    "Transactions"."currency";
