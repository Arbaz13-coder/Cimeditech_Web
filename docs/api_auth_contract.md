# CMX Web Portal - SGxBrokerAPI Authentication Contract

The Flutter client uses the authentication APIs found in the supplied SGxBrokerAPI project.

## Account API

Base route:

`POST /api/{var}/account/{action}`

Used actions:

- `login`
- `isvalidate`
- `signup`

### Login RData

```json
{
  "U_login_type": "WebLogin | ClientAppLogin",
  "U_login_sub_type": "Web | Android",
  "U_login_key": "MobileOrEmail",
  "U_DeviceID": "",
  "U_loginid": "mobile-or-email",
  "U_pwd": "password"
}
```

A successful response returns `RData.SvToken`, which the app stores with `flutter_secure_storage`.

## AUS OTP API

Base route:

`POST /api/aus/{var}/sendalerts/{action}`

Required headers in the current backend:

- `xRCT`
- `xRCK`

Used actions:

- `sendregotptoverifyuser`
- `sendregotptoresetpassword`
- `verifyotptoresetpassword`

### Registration OTP

Request RData:

```json
{
  "Name": "User Name",
  "MobileNo": "9876543210",
  "EmailID": "user@example.com"
}
```

Success returns `RData.OtpVerifyToken`.

### Complete registration

`POST /api/{var}/account/signup`

Important RRM values:

- `Text = OtpVerifyToken`
- `Message = mobile|otp`
- `RData = AA_Reg-compatible registration object`

### Reset password OTP

Request RData:

```json
{
  "MobileOrEmail": "9876543210"
}
```

Success returns `RData.OtpVerifyToken`. The current server also appends the associated mobile number to `Message`; the Flutter client supports both direct mobile input and email input.

### Complete password reset

Important RRM values:

- `Text = OtpVerifyToken`
- `Message = mobile|otp`
- `RData.R_reg_mobile_no = mobile`
- `RData.ConfirmPassword = new password`

## Current backend compatibility notes

1. Login sub-type accepts `Web`, `Desktop`, and `Android`, but not `iOS`. The Flutter iOS client therefore sends `Android` until the backend is updated.
2. Reset password validation checks `U_reg_loginid_mobile_email`, while the password update searches `U_reg_mobile_no`. The current method still proceeds to update the mobile-matched user, but the validation logic should be made consistent in the backend.
3. Flutter Web requires CORS to be enabled on the API when frontend and backend are on different origins.
4. `xRCK` cannot be treated as a true secret inside Flutter Web/mobile binaries. Consider replacing that scheme for production public clients.
