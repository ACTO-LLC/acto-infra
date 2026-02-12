# How to Review Azure Costs

This guide covers how to query Azure Cost Management data for the ACTO billing account using the Azure CLI REST API.

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- Billing account reader or Cost Management reader role on the billing account

## Key Identifiers

| Resource | Value |
|----------|-------|
| Billing Account ID | `d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31` |
| Budget Name | `monthly` |

The billing account scope is used for all queries below:

```
providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31
```

## Querying Costs

All cost queries use the Cost Management REST API via `az rest`. The general pattern is:

```bash
az rest --method post \
  --url "https://management.azure.com/<SCOPE>/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '<JSON_BODY>' \
  -o json
```

### Month-to-Date Costs by Subscription

```bash
az rest --method post ^
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31/providers/Microsoft.CostManagement/query?api-version=2023-11-01" ^
  --body "{\"type\":\"ActualCost\",\"timeframe\":\"MonthToDate\",\"dataset\":{\"granularity\":\"None\",\"aggregation\":{\"totalCost\":{\"name\":\"Cost\",\"function\":\"Sum\"}},\"grouping\":[{\"type\":\"Dimension\",\"name\":\"SubscriptionName\"}]}}" ^
  -o json
```

### Month-to-Date Costs by Service

Replace `SubscriptionName` with `ServiceName` in the grouping:

```bash
az rest --method post ^
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31/providers/Microsoft.CostManagement/query?api-version=2023-11-01" ^
  --body "{\"type\":\"ActualCost\",\"timeframe\":\"MonthToDate\",\"dataset\":{\"granularity\":\"None\",\"aggregation\":{\"totalCost\":{\"name\":\"Cost\",\"function\":\"Sum\"}},\"grouping\":[{\"type\":\"Dimension\",\"name\":\"ServiceName\"}]}}" ^
  -o json
```

### Custom Date Range (e.g., January 2026)

Use `timeframe: Custom` with a `timePeriod`:

```bash
az rest --method post ^
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31/providers/Microsoft.CostManagement/query?api-version=2023-11-01" ^
  --body "{\"type\":\"ActualCost\",\"timeframe\":\"Custom\",\"timePeriod\":{\"from\":\"2026-01-01T00:00:00Z\",\"to\":\"2026-01-31T23:59:59Z\"},\"dataset\":{\"granularity\":\"None\",\"aggregation\":{\"totalCost\":{\"name\":\"Cost\",\"function\":\"Sum\"}},\"grouping\":[{\"type\":\"Dimension\",\"name\":\"ServiceName\"}]}}" ^
  -o json
```

### Daily Costs for a Specific Service

Filter by service name and use daily granularity:

```bash
az rest --method post ^
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31/providers/Microsoft.CostManagement/query?api-version=2023-11-01" ^
  --body "{\"type\":\"ActualCost\",\"timeframe\":\"Custom\",\"timePeriod\":{\"from\":\"2026-02-09T00:00:00Z\",\"to\":\"2026-02-12T23:59:59Z\"},\"dataset\":{\"granularity\":\"Daily\",\"aggregation\":{\"totalCost\":{\"name\":\"Cost\",\"function\":\"Sum\"}},\"filter\":{\"dimensions\":{\"name\":\"ServiceName\",\"operator\":\"In\",\"values\":[\"SQL Database\"]}}}}" ^
  -o json
```

## Checking Budgets

List all budgets configured on the billing account:

```bash
az rest --method get ^
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/d7b28c4b-ea4c-50c1-92d9-e4a70d00cbdb:9f8a2b98-a9df-4616-a764-4db0a4dfff15_2019-05-31/providers/Microsoft.CostManagement/budgets?api-version=2023-11-01" ^
  -o json
```

The budget response includes:
- `properties.amount` — the budget limit
- `properties.currentSpend.amount` — actual spend so far this period
- `properties.forecastSpend.amount` — Azure's projected spend for the period
- `properties.notifications` — alert thresholds and contacts

## Listing Subscriptions

```bash
az account list --query "[?tenantId=='f8ac75ce-d250-407e-b8cb-e05f5b4cd913'].{Name:name, Id:id, State:state}" -o table
```

Current subscriptions:
- **ACTO Pay-As-You-Go** (`8883174d-a6ce-48b0-b0a1-c5ec5c397666`)
- **MCPP Subscription** (`a6f5a418-461f-42c0-a07a-90142521e5fb`)
- **Microsoft Azure Sponsorship** (`d487e16b-c758-4893-b0e9-a77c6e02e5f3`)
- **Microsoft Partner Network** (`243bc2e6-77b9-4b5c-9bd4-c8afddea58e0`)

## Notes

- The `az costmanagement` CLI extension is not used here; direct REST API calls via `az rest` are more reliable and don't require extra extensions.
- The `TheLastMonth` timeframe value is not supported at the billing account scope — use `Custom` with explicit dates instead.
- Grouping dimensions available include: `ServiceName`, `SubscriptionName`, `ResourceGroupName`, `ResourceType`, `MeterCategory`, `MeterSubCategory`.
