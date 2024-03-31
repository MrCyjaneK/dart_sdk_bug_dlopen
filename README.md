# dart_sdk_bug_dlopen

We have a dynamic library, that defines some symbols, in our case:


- `monero_libwallet2_api_c.so` defines `MONERO_Wallet_address`, which should get us a monero address (starting with a 4 or 8).
- `wownero_libwallet2_api_c.so` defines `WOWNERO_Wallet_address`,  which should get us a wownero address (starting with a W).

and this indeed works, until it entirely doesn't work. Minimal example can be seen in this repository.

## Preparation

Download and install monero_libwallet2_api_c.so and wownero_libwallet2_api_c.so files:

```bash
sudo wget https://static.mrcyjanek.net/monero_c/v0.18.3.3-RC11/monero/x86_64-linux-gnu_libwallet2_api_c.so.xz -O /usr/lib/monero_libwallet2_api_c.so.xz
sudo unxz /usr/lib/monero_libwallet2_api_c.so.xz
sudo wget https://static.mrcyjanek.net/monero_c/v0.18.3.3-RC11/wownero/x86_64-linux-gnu_libwallet2_api_c.so.xz -O /usr/lib/wownero_libwallet2_api_c.so.xz
sudo unxz /usr/lib/wownero_libwallet2_api_c.so.xz
```

## Reproducion

### [OK] 0000_wownero_ok.dart

This dart program ensures that the wownero library works properly

```bash
$ dart run bin/0000*.dart
monero: Wo3b.....irVAQ (should start with a W)
```

It should output correct address, if it fails, try re-doing preparation step.

### [OK] 0001_monero_ok.dart

This dart program ensures that the monero library works properly

```bash
$ dart run bin/0001*.dart
monero: 4A3o.....2Lg3q (should start with 4 or 8)
```

It should output correct address, if it fails, try re-doing preparation step.

#### [BAD] 0002_wownero_then_monero_bad.dart

```bash
$ dart run bin/0002*.dart 
wownero: Wo39....hFxoP (should start with W)
monero: Wo3f....Au8yT (should start with 4 or 8)
INVALID MONERO ADDRESS
```

This output doesn't match the expected output, as the library first loads `wownero_libwallet2_api_c.so`, and when it loads `monero_libwallet2_api_c.so` later it has all the symbols already defined (`tools::wallet`, and other wownero internal functions), what it doesn't have is the `MONERO_`* prefixed functions, and these are loaded no problem, as can be seen if we check for `sudo grep libwallet2 /proc/*/maps` (replace * with the PID.. or don't).

So my guess is that when we call `MONERO_` function (loaded from `monero_libwallet2_api_c.so`) we do call it, but the actual function, which calles "stuff" in monero codebase resolves to code from wownero, as the codebases are.. pretty much the same.

#### [BAD] 0003_monero_then_wowner_bad.dart

Same as above, but reversed.

#### [BAD] 0004_isolates_for_the_rescue_bad.dart

I had the idea that running the function in an isolate would make it open in a different PID (and a different process namespace.. maybe?), but it didn't work as expected.
```bash
$ sudo grep libwallet2 /proc/*/maps
{...}
/proc/24910/maps:7f9cc2641000-7f9cc2664000 rw-p 014f8000 ca:05 1577969                    /usr/lib/monero_libwallet2_api_c.so
/proc/24910/maps:7f9cc2712000-7f9cc2c9b000 r--p 00000000 ca:05 1577970                    /usr/lib/wownero_libwallet2_api_c.so
{...}
```

Turns out the libraries are loaded under the main PID. Which doesn't change much, as running every function call in an isolate is a non-solution anyway.


## Proposed solution

According to `man dlopen(3)`

> dlmopen()
> 
> This function performs the same task as dlopen()—the filename and flags arguments, as well as the return value, are the same, except for the differences noted below.
> 
> The dlmopen() function differs from dlopen() primarily in that it accepts an additional argument, lmid, that specifies the link-map list (also referred to as a namespace) in which the shared object should be loaded. (By comparison, dlopen() adds the dynamically loaded shared object to the same namespace as the shared object from which the dlopen() call is made.) The Lmid_t type is an opaque handle that refers to a namespace.
> 
> The lmid argument is either the ID of an existing namespace (which can be obtained using the dlinfo(3) RTLD_DI_LMID request) or one of the following special values:
> 
> LM_ID_BASE
>     Load the shared object in the initial namespace (i.e., the application's namespace).
> LM_ID_NEWLM
>     Create a new namespace and load the shared object in that namespace. The object must have been correctly linked to reference all of the other shared objects that it requires, since the new namespace is initially empty.
> 
> If filename is NULL, then the only permitted value for lmid is LM_ID_BASE.

And dart code currently uses `dlopen` in `void* Utils::LoadDynamicLibrary(const char* library_path, char** error) {` [as can be seen here](https://github.com/dart-lang/sdk/blob/9b2b0ac848af91baef45cd56c5b030fa3ef53c0b/runtime/platform/utils.cc#L298).

My proposed solution is to replace `handle = dlopen(library_path, RTLD_LAZY);` with `handle = dlmopen(LM_ID_NEWLM, library_path, RTLD_LAZY);`.

I got some compilation issues regarding the use of LM_ID_NEWLM, so I've hardcoded it to `-1` (according to `/usr/include/dlfcn.h` on ubuntu 20.04).

```patch
From eb86b73c22489e6647b2fffe2ed7207ddeb27e02 Mon Sep 17 00:00:00 2001
From: Czarek Nakamoto <cyjan@mrcyjanek.net>
Date: Sun, 31 Mar 2024 17:37:09 +0200
Subject: [PATCH] Isolate libraries when loading

---
 runtime/platform/utils.cc | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/runtime/platform/utils.cc b/runtime/platform/utils.cc
index e7179ed8040..b81bd594374 100644
--- a/runtime/platform/utils.cc
+++ b/runtime/platform/utils.cc
@@ -295,7 +295,7 @@ void* Utils::LoadDynamicLibrary(const char* library_path, char** error) {
 
 #if defined(DART_HOST_OS_LINUX) || defined(DART_HOST_OS_MACOS) ||              \
     defined(DART_HOST_OS_ANDROID) || defined(DART_HOST_OS_FUCHSIA)
-  handle = dlopen(library_path, RTLD_LAZY);
+  handle = dlmopen(-1, library_path, RTLD_LAZY);
 #elif defined(DART_HOST_OS_WINDOWS)
   SetLastError(0);  // Clear any errors.
 
-- 
2.25.1


```


undefined symbol: pthread_getspecific