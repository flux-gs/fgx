/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* lib/libutil_c/libutil.c -- the libutil umbrella: 2.11BSD usr.lib/libutil
 * (login.o logout.o logwtmp.o dkcksum.o), the login-accounting routines a
 * few programs link with `libs: util'.  dkcksum(3) is not here: it checksums
 * a disklabel, and FGX volumes carry none.
 *
 * Each member carries its own #includes; this file aggregates them into the
 * one TU that libutil.so and build/static_libs/libutil.s compile.
 */
#include "login.c"
#include "logout.c"
#include "logwtmp.c"
