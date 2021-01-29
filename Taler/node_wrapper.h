//
//  node_wrapper.h
//  Taler
//
//  Created by Jonathan Buchanan on 12/31/20.
//  Copyright © 2020 Taler. All rights reserved.
//

#ifndef node_wrapper_h
#define node_wrapper_h

#ifdef __cplusplus
extern "C" {
#endif

struct __IonoInstance;

struct __IonoInstance *
__new_instance();

void
__free_instance(struct __IonoInstance *instance);

// result must be freed!
char *
__eval_js(const char *js, struct __IonoInstance *instance);

void
__notify_instance(struct __IonoInstance *instance);

void
__run_node(struct __IonoInstance *instance);

void
__make_callback(const char *callback, struct __IonoInstance *instance);

void
__put_module_code(const char *module_name, const char *module_code, struct IonoInstance *instance);

#ifdef __cplusplus
}
#endif

#endif /* node_wrapper_h */
