/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
#ifndef node_wrapper_h
#define node_wrapper_h

#ifdef __cplusplus
extern "C" {
#endif

struct __IonoInstance;

struct __IonoInstance *
__initNative();

void
__destroyNative(struct __IonoInstance *instance);

char *
__evalJs(struct __IonoInstance *instance, const char *source);

void
__putModuleCodeNative(struct __IonoInstance *instance,
    const char *modName, const char *modCode);

void
__notifyNative(struct __IonoInstance *instance);

void
__runNode(struct __IonoInstance *instance);

void
__makeCallbackNative(struct __IonoInstance *instance, const char *source);

typedef void (* __NotifyHandler)(const char *payload, void *userdata);

void
__setNotifyHandler(struct __IonoInstance *instance, __NotifyHandler handler, void *userdata);

#ifdef __cplusplus
}
#endif

#endif /* node_wrapper_h */
