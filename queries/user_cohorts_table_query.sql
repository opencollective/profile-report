WITH 

    ActiveUsers AS (
        SELECT 
            "public"."Activities"."UserId" AS "UserId",
            "public"."Collectives"."slug" AS "UserSlug"
        FROM "public"."Activities"
        INNER JOIN "public"."Users"
        ON "Activities"."UserId" = "Users"."id"
        INNER JOIN "public"."Collectives"
        ON "Users"."CollectiveId" = "Collectives"."id"
        WHERE "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months'
        GROUP BY "public"."Activities"."UserId", "public"."Collectives"."slug"
    ),

    ExpenseActivities AS (
        SELECT 
            "public"."Activities"."id" AS "id",
            "public"."Activities"."UserId" AS "UserId",
            "UserCollectives"."slug" AS "UserSlug",
            CASE 
                WHEN "FromCollectives"."id" = "ToCollectives"."ParentCollectiveId" THEN 'Internal Collective Expense'
                WHEN "ToCollectives"."id" = "FromCollectives"."ParentCollectiveId" THEN 'Internal Collective Expense'
                WHEN "ToCollectives"."ParentCollectiveId" = "FromCollectives"."ParentCollectiveId" THEN 'Internal Collective Expense'
                WHEN 
                    CASE 
                        WHEN "Members"."role" = 'ADMIN' THEN TRUE
                        ELSE FALSE
                    END = TRUE THEN 'Expense to Own Collective'
                ELSE 'Expense'
            END AS "Expense Type"
        FROM "public"."Activities"
        INNER JOIN "public"."Users"
        ON "Activities"."UserId" = "Users"."id"
        INNER JOIN "public"."Collectives" AS "UserCollectives"
        ON "Users"."CollectiveId" = "UserCollectives"."id"
        INNER JOIN "public"."Collectives" AS "ToCollectives"
        ON "Activities"."CollectiveId" = "ToCollectives"."id"
        LEFT JOIN "public"."Collectives" AS "HostCollectives"
        ON "ToCollectives"."HostCollectiveId" = "HostCollectives"."id"
        LEFT JOIN "public"."Collectives" AS "FromCollectives" 
        ON "Activities"."FromCollectiveId" = "FromCollectives"."id"
        LEFT JOIN "public"."Members" 
        ON "FromCollectives"."id" = "Members"."MemberCollectiveId" 
        AND "ToCollectives"."id" = "Members"."CollectiveId" 
        AND "Members"."role" = 'ADMIN'
        WHERE 
            "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months' AND
            "public"."Activities"."type" IN (
                'collective.expense.created'
            )
    ),

    ExpenseToOwnCollective AS (
        WITH Counts AS (
            SELECT 
                EA."UserId" AS "UserId",
                EA."UserSlug" AS "UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                COUNT(*) AS "RowCount"
            FROM ExpenseActivities EA
            INNER JOIN "public"."Activities"
            ON EA."id" = "Activities"."id" AND "Expense Type" = 'Expense to Own Collective'
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "ToCollectives"
            ON "Activities"."CollectiveId" = "ToCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "ToCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months'
            AND "public"."Activities"."UserId" NOT IN (43478, 12457) -- Omit engineers sudharaka-palamakumbura and znarf
            GROUP BY EA."UserId", EA."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Expense Submitter Activities",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    ExpenseDirect AS (
        WITH Counts AS (
            SELECT 
                EA."UserId" AS "UserId",
                EA."UserSlug" AS "UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                COUNT(*) AS "RowCount"
            FROM ExpenseActivities EA
            INNER JOIN "public"."Activities"
            ON EA."id" = "Activities"."id" AND "Expense Type" = 'Expense'
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "ToCollectives"
            ON "Activities"."CollectiveId" = "ToCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "ToCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months'
            AND "public"."Activities"."UserId" NOT IN (43478, 12457) -- Omit engineers sudharaka-palamakumbura and znarf
            GROUP BY EA."UserId", EA."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Expense Submitter Activities",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),
    
    HostAdminActivities AS (
        WITH Counts AS (
            SELECT 
                "public"."Activities"."UserId" AS "UserId",
                "public"."Collectives"."slug" AS "UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                COUNT(*) AS "RowCount"
            FROM "public"."Activities"
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives"
            ON "Users"."CollectiveId" = "Collectives"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Activities"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE 
                "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months' AND
                "public"."Activities"."type" IN (
                    'collective.approved',
                    'collective.rejected',
                    'collective.expense.paid',
                    'collective.expense.incomplete',
                    'collective.expense.scheduledForPayment',
                    'collective.virtualcard.added',
                    'collective.virtualcard.deleted',
                    'collective.virtualcard.request.rejected',
                    'collective.virtualcard.request.approved',
                    'collective.expense.putOnHold',
                    'collective.expense.releasedFromHold',
                    'collective.expense.reApprovalRequested',
                    'collective.expense.unscheduledForPayment',
                    'agreement.created',
                    'agreement.edited'
                )
            AND "public"."Activities"."UserId" NOT IN (43478, 12457) -- Omit engineers sudharaka-palamakumbura and znarf
            GROUP BY "public"."Activities"."UserId", "public"."Collectives"."slug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Host Admin Activities",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    CollectiveAdminActivities AS (
        WITH Counts AS (
            SELECT 
                "public"."Activities"."UserId" AS "UserId",
                "public"."Collectives"."slug" AS "UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                COUNT(*) AS "RowCount"
            FROM "public"."Activities"
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives"
            ON "Users"."CollectiveId" = "Collectives"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Activities"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE 
                "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months' AND
                "public"."Activities"."type" IN (
                    'collective.created',
                    'collective.apply',
                    'collective.core.member.edited',
                    'collective.core.member.removed',
                    'collective.expense.approved',
                    'collective.expense.unapproved',
                    'collective.update.created'
                )
            AND "public"."Activities"."UserId" NOT IN (43478, 12457) -- Omit engineers sudharaka-palamakumbura and znarf
            GROUP BY "public"."Activities"."UserId", "public"."Collectives"."slug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Collective Admin Activities",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    ClassifiedOrders AS (
        SELECT 
            "public"."Orders"."id" AS "id",
            "public"."Orders"."createdAt",
            "public"."Orders"."CreatedByUserId" AS "CreatedByUserId",
            "UserCollectives"."slug" AS "UserSlug",
            CASE 
                WHEN "FromCollectives"."id" = "ToCollectives"."ParentCollectiveId" THEN 'Internal Collective Transfer'
                WHEN "ToCollectives"."id" = "FromCollectives"."ParentCollectiveId" THEN 'Internal Collective Transfer'
                WHEN "ToCollectives"."ParentCollectiveId" = "FromCollectives"."ParentCollectiveId" THEN 'Internal Collective Transfer'
                WHEN "PaymentMethods"."type" = 'host' THEN 'Contribution Via Host'
                WHEN "ToCollectives"."type" = 'EVENT' THEN 'Event Order'
                WHEN 
                    CASE 
                        WHEN "Members"."role" = 'ADMIN' THEN TRUE
                        ELSE FALSE
                    END = TRUE THEN 'Contribution to Own Collective'
                WHEN "FromCollectives"."type" = 'ORGANIZATION' THEN 'Contribution Via Organization'
                WHEN "FromCollectives"."slug" = "UserCollectives"."slug" THEN 'Direct Contribution'
                WHEN "FromCollectives"."slug" LIKE 'incognito-%' THEN 'Direct Contribution'
                WHEN "FromCollectives"."slug" LIKE 'guest-%' THEN 'Direct Contribution'
                ELSE 'Contribution Via Collective' 
            END AS "Contribution Type"
        FROM "public"."Orders"
        LEFT JOIN "public"."Users"
        ON "public"."Orders"."CreatedByUserId" = "public"."Users"."id"
        LEFT JOIN "public"."Collectives" AS "UserCollectives"
        ON "Users"."CollectiveId" = "UserCollectives"."id"
        LEFT JOIN "public"."Collectives" AS "FromCollectives" 
        ON "public"."Orders"."FromCollectiveId" = "FromCollectives"."id"
        LEFT JOIN "public"."Collectives" AS "ToCollectives"
        ON "public"."Orders"."CollectiveId" = "ToCollectives"."id"
        LEFT JOIN "public"."PaymentMethods" AS "PaymentMethods" 
        ON "public"."Orders"."PaymentMethodId" = "PaymentMethods"."id"
        LEFT JOIN "public"."Members" 
        ON "FromCollectives"."id" = "Members"."MemberCollectiveId" 
        AND "ToCollectives"."id" = "Members"."CollectiveId" 
        AND "Members"."role" = 'ADMIN'
        WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
        AND "public"."Orders"."status" IN ('PAID', 'ACTIVE', 'CANCELLED')
    ),

    EventOrders AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Event Order'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Event Orders",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    DirectContributions AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Direct Contribution'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Direct Contributions",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    ContributionsOwnCollective AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Contribution to Own Collective'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Contributions to Own Collective",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    CollectiveContributions AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Contribution Via Collective'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Collective Contributions",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    ContributionsViaHost AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Contribution Via Host'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Contributions Via Host",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),
    
    OrganizationContributions AS (
        WITH Counts AS (
            SELECT 
                CO."CreatedByUserId" AS "UserId",
                CO."UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                array_agg(distinct COALESCE("TargetCollectives"."slug", '_independent-or-host')) AS "Recipients",
                COUNT(*) AS "RowCount"
            FROM ClassifiedOrders CO
            INNER JOIN "public"."Orders"
            ON CO."id" = "public"."Orders"."id" AND CO."Contribution Type" = 'Contribution Via Organization'
            INNER JOIN "public"."Users"
            ON "Orders"."CreatedByUserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "TargetCollectives"
            ON "Orders"."CollectiveId" = "TargetCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "TargetCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Orders"."updatedAt" > NOW() - INTERVAL '12 months'
            AND "public"."Orders"."status" NOT IN ('EXPIRED', 'ERROR')
            GROUP BY CO."CreatedByUserId", CO."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Organization Contributions",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts",
            C."Recipients",
            cardinality(C."Recipients"::text[]) AS "Recipient Count"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    ),

    VirtualCardPurchases AS (

        WITH VP AS (
            SELECT 
                "public"."Activities"."id" AS "id",
                "public"."Activities"."UserId" AS "UserId",
                "UserCollectives"."slug" AS "UserSlug",
                'Virtual Card Purchase' AS "Expense Type"
            FROM "public"."Activities"
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "UserCollectives"
            ON "Users"."CollectiveId" = "UserCollectives"."id"
            INNER JOIN "public"."Collectives" AS "ToCollectives"
            ON "Activities"."CollectiveId" = "ToCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "ToCollectives"."HostCollectiveId" = "HostCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "FromCollectives" 
            ON "Activities"."FromCollectiveId" = "FromCollectives"."id"
            WHERE 
                "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months' AND
                "public"."Activities"."type" IN (
                    'virtualcard.purchase'
                )
        ),

        Counts AS (
            SELECT 
                VP."UserId" AS "UserId",
                VP."UserSlug" AS "UserSlug",
                array_agg(distinct COALESCE("HostCollectives"."slug", '_independent-or-host')) AS "Hosts",
                COUNT(*) AS "RowCount"
            FROM VP
            INNER JOIN "public"."Activities"
            ON VP."id" = "Activities"."id"
            INNER JOIN "public"."Users"
            ON "Activities"."UserId" = "Users"."id"
            INNER JOIN "public"."Collectives" AS "ToCollectives"
            ON "Activities"."CollectiveId" = "ToCollectives"."id"
            LEFT JOIN "public"."Collectives" AS "HostCollectives"
            ON "ToCollectives"."HostCollectiveId" = "HostCollectives"."id"
            WHERE "public"."Activities"."createdAt" > NOW() - INTERVAL '12 months'
            AND "public"."Activities"."UserId" NOT IN (43478, 12457) -- Omit engineers sudharaka-palamakumbura and znarf
            GROUP BY VP."UserId", VP."UserSlug"
        )

        SELECT 
            C."UserId",
            C."UserSlug",
            C."RowCount" AS "Virtual Card Purchases",
            LOG(C."RowCount") AS "LogScore",
            CAST(LOG(C."RowCount" + 1) AS FLOAT) / MAX(LOG(C."RowCount")) OVER() AS "ActivityScore",
            5 * ntile(20) OVER (ORDER BY C."RowCount") AS "Percentile",
            C."Hosts"
        FROM Counts C
        ORDER BY "ActivityScore" DESC, C."RowCount" DESC
    )

SELECT 
    "active-users"."UserId" AS "UserId",
    "active-users"."UserSlug" AS "UserSlug",
    COALESCE("expense-direct"."Expense Submitter Activities",0) AS "Expense Activities",
    COALESCE("expense-direct"."LogScore",0) AS "Log Expense Activities",
    COALESCE("expense-direct"."ActivityScore",0) AS "Expense Score",
    CASE
        WHEN "expense-direct"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("expense-direct"."ActivityScore"/0.33)
    END AS "Expense Rank",
    COALESCE("expense-direct"."Percentile",0) AS "Expense Percentile",
    "expense-direct"."Hosts" AS "Expense Hosts",
    COALESCE("expense-to-own-collective"."Expense Submitter Activities",0) AS "Expense to Own Collective Activities",
    COALESCE("expense-to-own-collective"."LogScore",0) AS "Log Expense to Own Collective Activities",
    COALESCE("expense-to-own-collective"."ActivityScore",0) AS "Expense to Own Collective Score",
    CASE
        WHEN "expense-to-own-collective"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("expense-to-own-collective"."ActivityScore"/0.33)
    END AS "Expense to Own Collective Rank",
    COALESCE("expense-to-own-collective"."Percentile",0) AS "Expense to Own Collective Percentile",
    "expense-to-own-collective"."Hosts" AS "Expense to Own Collective Hosts",
    COALESCE("host-admin-activities"."Host Admin Activities",0) AS "Host Admin Activities",
    COALESCE("host-admin-activities"."LogScore",0) AS "Log Host Admin Activities",
    COALESCE("host-admin-activities"."ActivityScore",0) AS "Host Admin Score",
    CASE
        WHEN "host-admin-activities"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("host-admin-activities"."ActivityScore"/0.33)
    END AS "Host Admin Rank",
    COALESCE("host-admin-activities"."Percentile",0) AS "Host Admin Percentile",
    "host-admin-activities"."Hosts" AS "Host Admin Hosts",
    COALESCE("collective-admin-activities"."Collective Admin Activities",0) AS "Collective Admin Activities",
    COALESCE("collective-admin-activities"."LogScore",0) AS "Log Collective Admin Activities",
    COALESCE("collective-admin-activities"."ActivityScore",0) AS "Collective Admin Score",
    CASE
        WHEN "collective-admin-activities"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("collective-admin-activities"."ActivityScore"/0.33)
    END AS "Collective Admin Rank",
    COALESCE("collective-admin-activities"."Percentile",0) AS "Collective Admin Percentile",
    "collective-admin-activities"."Hosts" AS "Collective Admin Hosts",
    COALESCE("event-orders"."Event Orders",0) AS "Event Orders",
    COALESCE("event-orders"."LogScore",0) AS "Log Event Orders",
    COALESCE("event-orders"."ActivityScore",0) AS "Event Orders Score",
    CASE
        WHEN "event-orders"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("event-orders"."ActivityScore"/0.33)
    END AS "Event Orders Rank",
    COALESCE("event-orders"."Percentile",0) AS "Event Orders Percentile",
    "event-orders"."Hosts" AS "Event Orders Hosts",
    "event-orders"."Recipients" AS "Event Orders Recipients",
    "event-orders"."Recipient Count" AS "Event Orders Recipient Count",
    COALESCE("direct-contributions"."Direct Contributions",0) AS "Direct Contributions",
    COALESCE("direct-contributions"."LogScore",0) AS "Log Direct Contributions",
    COALESCE("direct-contributions"."ActivityScore",0) AS "Direct Contributions Score",
    CASE
        WHEN "direct-contributions"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("direct-contributions"."ActivityScore"/0.33)
    END AS "Direct Contributions Rank",
    COALESCE("direct-contributions"."Percentile",0) AS "Direct Contributions Percentile",
    "direct-contributions"."Hosts" AS "Direct Contributions Hosts",
    "direct-contributions"."Recipients" AS "Direct Contributions Recipients",
    "direct-contributions"."Recipient Count" AS "Direct Contributions Recipient Count",
    COALESCE("contributions-own-collective"."Contributions to Own Collective",0) AS "Contributions to Own Collective",
    COALESCE("contributions-own-collective"."LogScore",0) AS "Log Contributions to Own Collective",
    COALESCE("contributions-own-collective"."ActivityScore",0) AS "Contributions to Own Collective Score",
    CASE
        WHEN "contributions-own-collective"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("contributions-own-collective"."ActivityScore"/0.33)
    END AS "Contributions to Own Collective Rank",
    COALESCE("contributions-own-collective"."Percentile",0) AS "Contributions to Own Collective Percentile",
    "contributions-own-collective"."Hosts" AS "Contributions to Own Collective Hosts",
    "contributions-own-collective"."Recipients" AS "Contributions to Own Collective Recipients",
    "contributions-own-collective"."Recipient Count" AS "Contributions to Own Collective Recipient Count",
    COALESCE("collective-contributions"."Collective Contributions",0) AS "Collective Contributions",
    COALESCE("collective-contributions"."LogScore",0) AS "Log Collective Contributions",
    COALESCE("collective-contributions"."ActivityScore",0) AS "Collective Contributions Score",
    CASE
        WHEN "collective-contributions"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("collective-contributions"."ActivityScore"/0.33)
    END AS "Collective Contributions Rank", 
    COALESCE("collective-contributions"."Percentile",0) AS "Collective Contributions Percentile",
    "collective-contributions"."Hosts" AS "Collective Contributions Hosts",
    "collective-contributions"."Recipients" AS "Collective Contributions Recipients",
    "collective-contributions"."Recipient Count" AS "Collective Contributions Recipient Count",
    COALESCE("contributions-via-host"."Contributions Via Host",0) AS "Contributions Via Host",
    COALESCE("contributions-via-host"."LogScore",0) AS "Log Contributions Via Host",
    COALESCE("contributions-via-host"."ActivityScore",0) AS "Contributions Via Host Score",
    CASE
        WHEN "contributions-via-host"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("contributions-via-host"."ActivityScore"/0.33)
    END AS "Contributions Via Host Rank",
    COALESCE("contributions-via-host"."Percentile",0) AS "Contributions Via Host Percentile",
    "contributions-via-host"."Hosts" AS "Contributions Via Host Hosts",
    "contributions-via-host"."Recipients" AS "Contributions Via Host Recipients",
    "contributions-via-host"."Recipient Count" AS "Contributions Via Host Recipient Count",
    COALESCE("organization-contributions"."Organization Contributions",0) AS "Organization Contributions",
    COALESCE("organization-contributions"."LogScore",0) AS "Log Organization Contributions",
    COALESCE("organization-contributions"."ActivityScore",0) AS "Organization Contributions Score",
    CASE
        WHEN "organization-contributions"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("organization-contributions"."ActivityScore"/0.33)
    END AS "Organization Contributions Rank",
    COALESCE("organization-contributions"."Percentile",0) AS "Organization Contributions Percentile",
    "organization-contributions"."Hosts" AS "Organization Contributions Hosts",
    "organization-contributions"."Recipients" AS "Organization Contributions Recipients",
    "organization-contributions"."Recipient Count" AS "Organization Contributions Recipient Count",
    COALESCE("virtual-card-purchases"."Virtual Card Purchases",0) AS "Virtual Card Purchases",
    COALESCE("virtual-card-purchases"."LogScore",0) AS "Log Virtual Card Purchases",
    COALESCE("virtual-card-purchases"."ActivityScore",0) AS "Virtual Card Purchases Score",
    CASE
        WHEN "virtual-card-purchases"."ActivityScore" IS NULL THEN 0
        ELSE CEILING("virtual-card-purchases"."ActivityScore"/0.33)
    END AS "Virtual Card Purchases Rank",
    COALESCE("virtual-card-purchases"."Percentile",0) AS "Virtual Card Purchases Percentile",
    "virtual-card-purchases"."Hosts" AS "Virtual Card Purchases Hosts"
FROM ActiveUsers AS "active-users"
LEFT JOIN ExpenseDirect AS "expense-direct"
ON "active-users"."UserId" = "expense-direct"."UserId"
LEFT JOIN ExpenseToOwnCollective AS "expense-to-own-collective"
ON "active-users"."UserId" = "expense-to-own-collective"."UserId"
LEFT JOIN HostAdminActivities AS "host-admin-activities"
ON "active-users"."UserId" = "host-admin-activities"."UserId"
LEFT JOIN CollectiveAdminActivities AS "collective-admin-activities"
ON "active-users"."UserId" = "collective-admin-activities"."UserId"
LEFT JOIN EventOrders AS "event-orders"
ON "active-users"."UserId" = "event-orders"."UserId"
LEFT JOIN DirectContributions AS "direct-contributions"
ON "active-users"."UserId" = "direct-contributions"."UserId"
LEFT JOIN ContributionsOwnCollective AS "contributions-own-collective"
ON "active-users"."UserId" = "contributions-own-collective"."UserId"
LEFT JOIN CollectiveContributions AS "collective-contributions"
ON "active-users"."UserId" = "collective-contributions"."UserId"
LEFT JOIN ContributionsViaHost AS "contributions-via-host"
ON "active-users"."UserId" = "contributions-via-host"."UserId"
LEFT JOIN OrganizationContributions AS "organization-contributions"
ON "active-users"."UserId" = "organization-contributions"."UserId"
LEFT JOIN VirtualCardPurchases AS "virtual-card-purchases"
ON "active-users"."UserId" = "virtual-card-purchases"."UserId"
ORDER BY "active-users"."UserId" ASC