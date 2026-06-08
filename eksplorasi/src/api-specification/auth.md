# API Specification - Auth

Dokumen ini menjelaskan API authentication berdasarkan requirement di [`api-requirement/user.md`](../api-requirement/user.md) dan schema Prisma pada model `User`.

## 1. Ruang Lingkup

API ini mencakup:

- login
- logout
- refresh token
- get current user

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- authentication menggunakan access token dan refresh token berbasis JWT
- login hanya berhasil jika user berstatus `aktif`
- logout bersifat mengakhiri sesi refresh token di server
- access token yang sudah terbit tetap valid sampai expiry, kecuali ada blacklist tambahan
- response user pada endpoint auth mengikuti aturan enum yang sama dengan spec users:
  - role memakai value `@map`
  - status memakai value `@map`

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Common Response Format

### 4.1 Success

```json
{
  "success": true,
  "message": "OK",
  "data": {}
}
```

### 4.2 Error

```json
{
  "success": false,
  "message": "Unauthorized",
  "errorCode": "UNAUTHORIZED",
  "errors": []
}
```

## 5. User Object

User object yang dikembalikan pada endpoint auth:

```json
{
  "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
  "userId": "USR-0001",
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "role": "super_admin",
  "status": "aktif",
  "createdAt": "2026-06-08T10:00:00.000Z",
  "updatedAt": "2026-06-08T10:00:00.000Z",
  "deletedAt": null
}
```

## 6. API - Authentication

### 6.1 Login

`POST /api/auth/login`

Login menggunakan `email` dan `password`.

#### Request Body

```json
{
  "email": "budi@example.com",
  "password": "Secret123!"
}
```

#### Validasi

- `email`
  - wajib
  - format email valid
- `password`
  - wajib

#### Response 200

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "tokenType": "Bearer",
    "expiresIn": 3600,
    "user": {
      "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
      "userId": "USR-0001",
      "name": "Budi Santoso",
      "email": "budi@example.com",
      "role": "super_admin",
      "status": "aktif",
      "createdAt": "2026-06-08T10:00:00.000Z",
      "updatedAt": "2026-06-08T10:00:00.000Z",
      "deletedAt": null
    }
  }
}
```

#### Behavior

- login hanya berhasil jika user berstatus `aktif`
- jika password salah atau user tidak ditemukan, response harus tetap generik untuk menghindari user enumeration

### 6.2 Logout

`POST /api/auth/logout`

Logout menggunakan refresh token atau token sesi aktif.

#### Request Body

```json
{
  "refreshToken": "eyJhbGciOi..."
}
```

#### Behavior

- refresh token dinonaktifkan dari sisi server
- access token yang sudah terbit tetap valid sampai expiry, kecuali ada mekanisme blacklist tambahan

#### Response 200

```json
{
  "success": true,
  "message": "Logout successful",
  "data": null
}
```

### 6.3 Refresh Token

`POST /api/auth/refresh-token`

Menerbitkan access token baru menggunakan refresh token.

#### Request Body

```json
{
  "refreshToken": "eyJhbGciOi..."
}
```

#### Response 200

```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
}
```

#### Behavior

- jika refresh token valid, server boleh melakukan token rotation
- jika token sudah expired atau tidak valid, request ditolak

### 6.4 Get Current User

`GET /api/auth/me`

Mengambil data user yang sedang login berdasarkan access token.

#### Headers

```http
Authorization: Bearer <accessToken>
```

#### Response 200

```json
{
  "success": true,
  "message": "Current user fetched successfully",
  "data": {
    "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
    "userId": "USR-0001",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "role": "super_admin",
    "status": "aktif",
    "createdAt": "2026-06-08T10:00:00.000Z",
    "updatedAt": "2026-06-08T10:00:00.000Z",
    "deletedAt": null
  }
}
```

## 7. Error Codes

### 7.1 Common Error Codes

- `VALIDATION_ERROR`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `NOT_FOUND`
- `CONFLICT`
- `INTERNAL_SERVER_ERROR`

### 7.2 Recommended HTTP Status Codes

- `200 OK`
- `400 Bad Request`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `409 Conflict`
- `500 Internal Server Error`

## 8. Validation Rules Summary

### 8.1 Login

- `email`: required, valid email
- `password`: required

### 8.2 Logout

- `refreshToken`: required

### 8.3 Refresh Token

- `refreshToken`: required

## 9. Notes Implementasi

- response auth tidak boleh mengembalikan password
- jika aplikasi membutuhkan pengelolaan sesi yang lebih ketat, refresh token sebaiknya disimpan pada session table terpisah
- jika nanti dibutuhkan endpoint reset password atau change password, sebaiknya dibuat terpisah dari auth dasar
