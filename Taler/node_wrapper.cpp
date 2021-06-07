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
#include "node_wrapper.h"

#include <map>
#include <string>

#include "node.h"
#include "uv.h"

struct __IonoInstance
{
    /* Node/V8 */
    static std::unique_ptr<node::MultiIsolatePlatform> platform;
    std::unique_ptr<node::CommonEnvironmentSetup> setup;
    v8::Isolate *isolate;
    node::Environment *env;
    uv_async_t async_notify;
    
    bool break_requested;
    std::map<std::string, std::string> modmap;
    
    /* Notifications to swift */
    __NotifyHandler notification_handler;
    void *notification_userdata;
    
    __IonoInstance();
    
    char *
    evalJs(const char *js);
    
    void
    runNode();
    
    void
    makeCallback(const char *callback);
};

#ifdef __cplusplus
extern "C" {
#endif

struct __IonoInstance *
__initNative()
{
    __IonoInstance *instance = new __IonoInstance();
    return instance;
}

void
__destroyNative(struct __IonoInstance *instance)
{
    delete instance;
}

char *
__evalJs(struct __IonoInstance *instance, const char *js)
{
    return instance->evalJs(js);
}

void
__putModuleCodeNative(struct __IonoInstance *instance,
    const char *modName, const char *modCode)
{
    instance->modmap[std::string(modName)] = std::string(modCode);
}

void
__notifyNative(struct __IonoInstance *instance)
{
    uv_async_send(&instance->async_notify);
}

void
__runNode(struct __IonoInstance *instance)
{
    instance->runNode();
}

void
__makeCallbackNative(struct __IonoInstance *instance, const char *source)
{
    instance->makeCallback(source);
}

void
__setNotifyHandler(struct __IonoInstance *instance, __NotifyHandler handler, void *userdata)
{
    instance->notification_handler = handler;
    instance->notification_userdata = userdata;
}

#ifdef __cplusplus
}
#endif

std::unique_ptr<node::MultiIsolatePlatform> __IonoInstance::platform = nullptr;

static void
notifyCallback(uv_async_t *async);

static void
sendMessageCallback(const v8::FunctionCallbackInfo<v8::Value> &args);

static const std::string main_code = "global.__node_run = (x) => {"
                                   "  0 && console.log('running code', x);"
                                   "  global.eval(x);"
                                   "};"
                                   ""
                                   "global.__iono_onMessage = (x) => {"
                                   "  0 && console.log('got __iono_onMessage', x);"
                                   "};";

__IonoInstance::__IonoInstance() :
    break_requested(false),
    modmap(),
    notification_handler(nullptr)
{
    {
        uv_loop_t *loop = uv_default_loop();
        uv_async_init(loop, &async_notify, &notifyCallback);
        async_notify.data = this;
    }
    
    std::vector<std::string> args = { "node" };
    std::vector<std::string> exec_args;
    std::vector<std::string> errors;
    
    if (nullptr == platform)
    {
        int exit_code = node::InitializeNodeWithArgs(&args, &exec_args, &errors);
        for (const std::string &error : errors)
        {
            fprintf(stderr, "%s: %s\n", args[0].c_str(), error.c_str());
            /*if (exit_code != 0) {
                return exit_code;*/
        }

        platform = node::MultiIsolatePlatform::Create(4);
        v8::V8::InitializePlatform(platform.get());
        v8::V8::Initialize();
    }

    setup = node::CommonEnvironmentSetup::Create(platform.get(), &errors, args, exec_args);
    if (!setup) {
        for (const std::string &err : errors)
            fprintf(stderr, "%s: %s\n", args[0].c_str(), err.c_str());
            //return 1;
    }

    isolate = setup->isolate();
    env = setup->env();

    {
        v8::Locker locker(isolate);
        v8::Isolate::Scope isolate_scope(isolate);
        v8::HandleScope handle_scope(isolate);
        v8::Context::Scope context_scope(setup->context());

        node::LoadEnvironment(env, main_code.c_str());
        
        v8::Local<v8::ObjectTemplate> data_template = v8::ObjectTemplate::New(isolate);
        data_template->SetInternalFieldCount(1);
        v8::Local<v8::Object> data_object = data_template->NewInstance(setup->context()).ToLocalChecked();
        data_object->SetAlignedPointerInInternalField(0, this);

        v8::Local<v8::Function> sendMessageFunction = v8::Function::New(setup->context(),
            sendMessageCallback,
            data_object).ToLocalChecked();

        v8::Local<v8::Object> global = setup->context()->Global();

        global->Set(setup->context(), v8::String::NewFromUtf8(isolate, "__iono_sendMessage",
            v8::NewStringType::kNormal).ToLocalChecked(),
            sendMessageFunction).Check();
    }
}

char *
__IonoInstance::evalJs(const char *js)
{
    v8::Locker locker(isolate);
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Context::Scope context_scope(setup->context());

    // Create a string containing the JavaScript source code.
    v8::Local<v8::String> source =
        v8::String::NewFromUtf8(isolate, js, v8::NewStringType::kNormal).ToLocalChecked();

    // Compile the source code.
    v8::Local<v8::Script> script;
    if (!v8::Script::Compile(setup->context(), source).ToLocal(&script)) {
        return nullptr;
    }

    // Run the script to get the result.
    v8::Local<v8::Value> result;
    if (!script->Run(setup->context()).ToLocal(&result)) {
        return nullptr;
    }

    // Convert the result to an UTF8 string and print it.
    v8::String::Utf8Value utf8(isolate, result);
    return strdup(*utf8);
}

void
__IonoInstance::runNode() {
    v8::Locker locker(isolate);
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Context::Scope context_scope(setup->context());
    break_requested = false;
    while (true) {
        uv_run(uv_default_loop(), UV_RUN_ONCE);
        platform->DrainTasks(isolate);
        if (break_requested)
            break;
    }
}

void
__IonoInstance::makeCallback(const char *callback)
{
    v8::Locker locker(isolate);
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Context::Scope context_scope(setup->context());
    v8::Local<v8::Object> global = setup->context()->Global();
    v8::Local<v8::Value> argv[] = {
        v8::String::NewFromUtf8(isolate, callback,
            v8::NewStringType::kNormal).ToLocalChecked()
    };
    node::MakeCallback(isolate, global, "__node_run", 1, argv, {0, 0});
}

static void
notifyCallback(uv_async_t *async) {
    __IonoInstance *instance = (__IonoInstance *)async->data;
    instance->break_requested = true;
}

static void
sendMessageCallback(const v8::FunctionCallbackInfo<v8::Value> &args) {
    v8::Isolate *isolate = args.GetIsolate();
    v8::Locker locker(isolate);
    if (args.Length() < 1)
        return;
    v8::HandleScope scope(isolate);
    v8::Local<v8::Value> arg = args[0];
    v8::String::Utf8Value value(isolate, arg);

    v8::Local<v8::Object> data = v8::Local<v8::Object>::Cast(args.Data());

    __IonoInstance *instance = (__IonoInstance *)data->GetAlignedPointerFromInternalField(0);
    instance->notification_handler(*value, instance->notification_userdata);
}
