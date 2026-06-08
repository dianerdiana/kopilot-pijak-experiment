# API Specification - Users

Dokumen ini menjelaskan API untuk manajemen user berdasarkan requirement di [`api-requirement/user.md`](../api-requirement/user.md) dan schema Prisma pada model `User`.

## 1. Ruang Lingkup

API ini mencakup:

- create user
- get list user
- get user by id
- update user
- delete user

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- User memakai model `User` pada `schema.prisma`
- `userId` adalah identifier bisnis yang ditampilkan ke client, sedangkan `id` adalah primary key internal
- `deletedAt` dipakai untuk soft delete
- password disimpan dalam bentuk hash pada kolom `password`
- role yang tersedia mengikuti enum Prisma dan frontend menerima nilai `@map`-nya:
  - `SuperAdmin` -> `super_admin`
  - `Manager` -> `manager`
- status user mengikuti enum Prisma dan frontend menerima nilai `@map`-nya:
  - `Active` -> `aktif`
  - `Inactive` -> `tidak_aktif`
- list user menggunakan pagination standar

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Model Data

### 4.1 User

Representasi user yang dikembalikan ke client:

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

### 4.2 Field Rules

- `id`
  - type: string
  - UUID internal
  - read-only
- `userId`
  - type: string
  - unique
  - readable dan dapat dipakai sebagai kode user bisnis
- `name`
  - type: string
  - wajib
- `email`
  - type: string
  - wajib
  - unique
- `password`
  - type: string
  - hanya ada pada request create/update password
  - tidak pernah dikembalikan dalam response
- `role`
  - type: enum
  - nilai frontend mengikuti `@map` enum Prisma:
    - `super_admin`
    - `manager`
- `status`
  - type: enum
  - nilai frontend mengikuti `@map` enum Prisma:
    - `aktif`
    - `tidak_aktif`
- `createdAt`
  - type: datetime
  - read-only
- `updatedAt`
  - type: datetime
  - read-only
- `deletedAt`
  - type: datetime | null
  - read-only dari response
  - bernilai `null` jika user belum dihapus

## 5. Common Response Format

### 5.1 Success

```json
{
  "success": true,
  "message": "OK",
  "data": {}
}
```

### 5.2 Error

```json
{
  "success": false,
  "message": "Validation failed",
  "errorCode": "VALIDATION_ERROR",
  "errors": []
}
```

## 6. API - Manajemen User

### 6.1 Create User

`POST /api/users`

Digunakan untuk membuat user baru.

#### Request Body

```json
{
  "userId": "USR-0001",
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "Secret123!",
  "role": "manager",
  "status": "aktif"
}
```

#### Validasi

- `userId`
  - wajib
  - unik
- `name`
  - wajib
  - minimal 3 karakter
- `email`
  - wajib
  - format email valid
  - unik
- `password`
  - wajib
  - minimal 8 karakter
  - disarankan mengandung huruf besar, huruf kecil, angka, dan simbol
- `role`
  - wajib
  - harus salah satu dari value enum yang sudah di-map:
    - `super_admin`
    - `manager`
- `status`
  - opsional, default `aktif`

#### Response 201

```json
{
  "success": true,
  "message": "User created successfully",
  "data": {
    "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
    "userId": "USR-0001",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "role": "manager",
    "status": "aktif",
    "createdAt": "2026-06-08T10:00:00.000Z",
    "updatedAt": "2026-06-08T10:00:00.000Z",
    "deletedAt": null
  }
}
```

### 6.2 Get List User

`GET /api/users`

Digunakan untuk mengambil daftar user.

#### Query Params

- `page`
  - optional
  - default: `1`
- `limit`
  - optional
  - default: `10`
- `search`
  - optional
  - pencarian berdasarkan `name`, `email`, atau `userId`
- `role`
  - optional
  - filter berdasarkan role
- `status`
  - optional
  - filter berdasarkan status
- `includeDeleted`
  - optional
  - default: `false`

#### Response 200

```json
{
  "success": true,
  "message": "User list fetched successfully",
  "data": {
    "items": [
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
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "totalItems": 1,
      "totalPages": 1
    }
  }
}
```

### 6.3 Get User By ID

`GET /api/users/:id`

Mengambil detail user berdasarkan `id`.

#### Path Params

- `id`
  - UUID user

#### Response 200

```json
{
  "success": true,
  "message": "User detail fetched successfully",
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

### 6.4 Update User

`PUT /api/users/:id`

Mengupdate data user.

#### Path Params

- `id`
  - UUID user

#### Request Body

```json
{
  "userId": "USR-0001",
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "NewSecret123!",
  "role": "manager",
  "status": "aktif"
}
```

#### Validasi

- semua field bersifat optional, tetapi minimal harus ada satu field yang diubah
- `email` harus valid dan unik
- `password` opsional
  - jika dikirim, minimal 8 karakter
  - jika kosong atau tidak dikirim, password tidak diupdate
- `role` harus sesuai value enum yang sudah di-map
  - `super_admin`
  - `manager`
- `status` harus sesuai enum

#### Response 200

```json
{
  "success": true,
  "message": "User updated successfully",
  "data": {
    "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
    "userId": "USR-0001",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "role": "manager",
    "status": "aktif",
    "createdAt": "2026-06-08T10:00:00.000Z",
    "updatedAt": "2026-06-08T11:00:00.000Z",
    "deletedAt": null
  }
}
```

### 6.5 Delete User

`DELETE /api/users/:id`

Menghapus user dengan pendekatan soft delete.

#### Path Params

- `id`
  - UUID user

#### Behavior

- `deletedAt` diisi dengan timestamp saat penghapusan
- user tidak dihapus permanen dari database
- user yang sudah dihapus tidak muncul di list default

#### Response 200

```json
{
  "success": true,
  "message": "User deleted successfully",
  "data": {
    "id": "c8bdc2d3-6c2e-4d52-a6c0-1db4dd6c61f2",
    "deletedAt": "2026-06-08T12:00:00.000Z"
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
- `201 Created`
- `400 Bad Request`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `409 Conflict`
- `500 Internal Server Error`

## 8. Validation Rules Summary

### 8.1 Create User

- `userId`: required, unique
- `name`: required, min 3 chars
- `email`: required, valid email, unique
- `password`: required, min 8 chars
- `role`: required, enum value `super_admin` atau `manager`
- `status`: optional, enum value `aktif` atau `tidak_aktif`

### 8.2 Update User

- field boleh parsial
- `email` tetap harus valid dan unik bila diubah
- `password` opsional dan hanya diupdate jika diisi
- `role` harus sesuai enum value `super_admin` atau `manager`
- `status` harus sesuai enum value `aktif` atau `tidak_aktif`

## 9. Notes Implementasi

- Untuk endpoint list dan detail, password tidak boleh ikut dikembalikan
- Jika ada kebutuhan audit, `deletedAt` lebih disarankan daripada hard delete
- Jika nanti dibutuhkan reset password atau change password, sebaiknya dibuat endpoint terpisah agar perubahan credential tidak bercampur dengan update profil
