# User Mapping Frontend

## Routes used

```text
POST /api/app/{apiVersion}/admin/getregcompanywithuser
POST /api/app/{apiVersion}/usermapping/mastertypes
POST /api/app/{apiVersion}/usermapping/users
POST /api/app/{apiVersion}/usermapping/get
POST /api/app/{apiVersion}/usermapping/save
```

All calls include:

```http
Content-Type: application/json
xRUT: <SvToken>
```


## Companies

The company selector uses the existing authenticated `GetRegCompanyWithUser` endpoint and reads `RData.CompanyList`:

```json
{
  "CompanyList": [
    {
      "O_id": 3,
      "O_name": "Example Company",
      "O_acc_books_start_xdt": "2026-04-01T00:00:00"
    }
  ]
}
```

The selected `O_id` is sent as `company_id` to `users`, `get`, and `save`.

## Master types

Request:

```json
{
  "RAction": "L",
  "RData": {}
}
```

The frontend reads `RData.vRows` with `master_type` and `master_name`.

## Users

Request:

```json
{
  "RAction": "L",
  "RData": {
    "company_id": 1,
    "Search": ""
  }
}
```

The frontend reads `RData.vRows` containing `user_id`, `user_name`, `login_id`, `user_type`, and `status`.

## Mapping

Request:

```json
{
  "RAction": "L",
  "RData": {
    "user_id": 15,
    "company_id": 1,
    "master_type": "Item",
    "Search": "",
    "RPageNo": 1,
    "RPageSize": 100
  }
}
```

Response fields used:

- `select_all`
- `select_value`
- `RCount`
- `RPageNo`
- `RPageSize`
- `RTotalPages`
- `vRows[]` containing `Id`, `Name`, `Group`, `IsSelected`

`select_value` contains the complete explicit selection, which lets the Flutter page preserve selections while moving between server-side pages.

## Save

Explicit selection:

```json
{
  "RAction": "IUO",
  "RData": {
    "user_id": 15,
    "company_id": 1,
    "master_type": "Item",
    "select_all": false,
    "select_value": [101, 102, 105]
  }
}
```

Select All:

```json
{
  "RAction": "IUO",
  "RData": {
    "user_id": 15,
    "company_id": 1,
    "master_type": "Item",
    "select_all": true,
    "select_value": []
  }
}
```

Revoke All:

```json
{
  "RAction": "IUO",
  "RData": {
    "user_id": 15,
    "company_id": 1,
    "master_type": "Item",
    "select_all": false,
    "select_value": []
  }
}
```
