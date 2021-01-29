//
//  node_wrapper.cpp
//  Taler
//
//  Created by Jonathan Buchanan on 12/31/20.
//  Copyright © 2020 Taler. All rights reserved.
//

#include <map>
#include <string>

#include "node.h"
#include "uv.h"

struct __IonoInstance
{
    static std::unique_ptr<node::MultiIsolatePlatform> platform;
    std::unique_ptr<node::CommonEnvironmentSetup> setup;
    v8::Isolate *isolate;
    node::Environment *env;
    uv_async_t async_notify;
    bool break_requested;
    std::map<std::string, std::string> modmap;
    
    __IonoInstance();
    
    char *
    eval_js(const char *js);
    
    void
    run_node();
    
    void
    make_callback(const char *callback);
};

#ifdef __cplusplus
extern "C" {
#endif

struct __IonoInstance *
__new_instance()
{
    __IonoInstance *instance = new __IonoInstance();
    return instance;
}

void
__free_instance(struct __IonoInstance *instance)
{
    delete instance;
}

char *
__eval_js(const char *js, struct __IonoInstance *instance)
{
    return instance->eval_js(js);
}

void
__notify_instance(struct __IonoInstance *instance)
{
    uv_async_send(&instance->async_notify);
}

void
__run_node(struct __IonoInstance *instance)
{
    instance->run_node();
}

void
__make_callback(const char *callback, struct __IonoInstance *instance)
{
    instance->make_callback(callback);
}

void
__put_module_code(const char *module_name, const char *module_code, struct __IonoInstance *instance)
{
    instance->modmap[std::string(module_name)] = std::string(module_code);
}

#ifdef __cplusplus
}
#endif

std::unique_ptr<node::MultiIsolatePlatform> __IonoInstance::platform = nullptr;

static void
notify_callback(uv_async_t *async);

static void
send_message_callback(const v8::FunctionCallbackInfo<v8::Value> &args);

__IonoInstance::__IonoInstance() :
    break_requested(false),
    modmap()
{
    {
        uv_loop_t *loop = uv_default_loop();
        uv_async_init(loop, &async_notify, &notify_callback);
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

        v8::MaybeLocal<v8::Value> loadenv_ret = node::LoadEnvironment(
            env,
            "const publicRequire ="
            "  require('module').createRequire(process.cwd() + '/');"
            "globalThis.require = publicRequire;"
            "global.__node_run = (x) => {"
            "  0 && console.log('running code', x);"
            "  global.eval(x);"
            "};");
        
        v8::Local<v8::ObjectTemplate> data_template = v8::ObjectTemplate::New(isolate);
        data_template->SetInternalFieldCount(1);
        v8::Local<v8::Object> data_object = data_template->NewInstance(setup->context()).ToLocalChecked();
        data_object->SetAlignedPointerInInternalField(0, this);

        v8::Local<v8::Function> sendMessageFunction = v8::Function::New(setup->context(),
            send_message_callback,
            data_object).ToLocalChecked();

        v8::Local<v8::Object> global = setup->context()->Global();

        global->Set(setup->context(), v8::String::NewFromUtf8(isolate, "__iono_sendMessage",
            v8::NewStringType::kNormal).ToLocalChecked(),
            sendMessageFunction).Check();
    }
}

char *
__IonoInstance::eval_js(const char *js)
{
    v8::Locker locker(isolate);
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Context::Scope context_scope(setup->context());

    {
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
}

void
__IonoInstance::run_node() {
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
__IonoInstance::make_callback(const char *callback)
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
notify_callback(uv_async_t *async) {
    __IonoInstance *instance = (__IonoInstance *)async->data;
    instance->break_requested = true;
}

static void
send_message_callback(const v8::FunctionCallbackInfo<v8::Value> &args) {
    v8::Isolate *isolate = args.GetIsolate();
    v8::Locker locker(isolate);
    if (args.Length() < 1) return;
    v8::HandleScope scope(isolate);
    v8::Local<v8::Value> arg = args[0];
    v8::String::Utf8Value value(isolate, arg);

    v8::Local<v8::Object> data = v8::Local<v8::Object>::Cast(args.Data());

    __IonoInstance *instance = (__IonoInstance *)data->GetAlignedPointerFromInternalField(0);

    /*JNIEnv *env = myInstance->currentJniEnv;

    if (env == nullptr) {
        mylog("FATAL: JNI env is nullptr");
        return;
    }

    jclass clazz = env->FindClass("akono/AkonoJni");

    if (clazz == nullptr) {
        mylog("FATAL: class not found");
        return;
    }

    jstring payloadStr = env->NewStringUTF(*value);

    jmethodID meth = env->GetMethodID(clazz, "internalOnNotify", "(Ljava/lang/String;)V");

    if (meth == nullptr) {
        mylog("FATAL: method not found");
        return;
    }

    env->CallVoidMethod(myInstance->currentJniThiz, meth, payloadStr);*/
}
