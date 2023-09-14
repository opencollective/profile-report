SELECT 
    COALESCE("Collectives"."ParentCollectiveId", "Transactions"."CollectiveId") AS "CollectiveId",
    "Transactions"."HostCollectiveId" AS "HostCollectiveId",
    COALESCE("PaymentMethods"."type", 'blank') AS "PaymentMethodType",
    "Transactions"."currency" AS "currency",
    COUNT("Transactions"."id") AS "transactionCount",
    SUM("Transactions"."amount") AS "totalAmount",
    SUM("Orders"."platformTipAmount") AS "platformTipAmount"
FROM 
    "public"."Transactions" AS "Transactions"
LEFT JOIN "public"."PaymentMethods" AS "PaymentMethods"
ON "Transactions"."PaymentMethodId" = "PaymentMethods"."id"
LEFT JOIN "public"."Collectives" AS "Collectives"
ON "Transactions"."CollectiveId" = "Collectives"."id"
LEFT JOIN "public"."Orders" AS "Orders"
ON "Transactions"."OrderId" = "Orders"."id"
WHERE 
    "Transactions"."createdAt" >= DATE_TRUNC('month', NOW() - INTERVAL '12 month')
    AND "Transactions"."createdAt" < DATE_TRUNC('month', NOW())
    AND "Transactions"."type" = 'CREDIT'
    AND "Transactions"."kind" IN ('ADDED_FUNDS','CONTRIBUTION','PREPAID_PAYMENT_METHOD')
    AND "Collectives"."type" IN ('COLLECTIVE', 'EVENT', 'PROJECT')
GROUP BY
    COALESCE("Collectives"."ParentCollectiveId", "Transactions"."CollectiveId"),
    "Transactions"."HostCollectiveId",
    "PaymentMethodType",
    "Transactions"."currency";