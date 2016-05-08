spawn   = require('child_process').spawn
Bot     = require 'node-telegram-bot'
timeout = 120000 # in ms
token   = 'YOUR_TOKEN_HERE'

strings =
    check_docker: "Checking Docker installation & download latest node image."
    docker_check_not_ok: "Please check your Docker installation. Make sure 'docker run --rm node' can be executed normally."
    docker_check_ok: "Docker installation check OK & node image has been downloaded and ready."
    err_code_type: "Sorry {name}! You have to give me the node.js code(in string) so I can evaluate that for you!"
    help: "Hello {name}!\nYou can tell me what node.js code I need to evaluate, and I will give you the result.\nIn groups, use /evaluate command to give me the code. In private messages, just send me the code and I will evaluate that for you.\nYou can call installModule(\"module1\", \"module2\"(, ...), callback) to install NPM modules and require them in the script.\nAfter " + timeout/1000 + " seconds of execution, the script will timeout and be killed."
    end: "** Script execution ended with code {code} **"
    startEvaluate: "** Script started executing, the execution timeout is " + timeout/1000 + " seconds. The result will be sent to you after execution (up to " + timeout/1000 + " seconds). Notice that everything will be deleted permanently after execution. **"
    timeout: "** Script execution timed out, killing the script. (" + timeout/1000 + " seconds) **"

installModuleCode = 'function installModule() {\
                        var modules = "";\
                        var callback;\
                        for (var i in arguments) {\
                            if (typeof arguments[i] != "function") {\
                                modules += arguments[i] + " ";\
                            } else {\
                                callback = arguments[i];\
                            }\
                        }\
                        if (!callback) {\
                            console.log("Callback needed! For example: installModule(\'module1\', \'module2\', function () {.....})");\
                            process.exit(-1);\
                        }\
                        require("child_process").exec("npm install " + modules.trim(), (error, stdout, stderr) => {\
                            callback();\
                        });\
                        return 0;
                    }'

if !Date.now
    Date.now = -> return new Date().getTime()

console.log strings.check_docker

spawn('docker', ['run', '--rm', 'node']).on 'close', (code) ->
    if code != 0
        console.log strings.docker_check_not_ok
        process.exit -1

    console.log strings.docker_check_ok

    bot = new Bot(
        token: token
    ).on('message', (message) ->
        console.log "@#{message.from.username}: #{message.text}"

        if !message.text?
            if message.chat.type == "group"
                return

            bot.sendMessage
                chat_id: message.chat.id
                reply_to_message_id: message.message_id
                text: strings.err_code_type.replace /{name}/gi, message.from.first_name
            return

        if message.text.indexOf("/start") == 0 or message.text.indexOf("/help") == 0
            bot.sendMessage
                chat_id: message.chat.id
                reply_to_message_id: message.message_id
                text: strings.help.replace /{name}/gi, message.from.first_name
            return

        if message.chat.type == "group"
            if message.text.indexOf("/evaluate") == -1
                return
            else
                message.text = message.text.slice 10

        code = installModuleCode + message.text

        containerName     = Date.now().toString()
        executionFinished = false
        result            = ""

        bot.sendMessage
            chat_id: message.chat.id
            reply_to_message_id: message.message_id
            text: strings.startEvaluate

        setTimeout ->
            if !executionFinished
                spawn('docker', ['rm', '-f', containerName]).on 'close', (code) ->
                    bot.sendMessage
                        chat_id: message.chat.id
                        reply_to_message_id: message.message_id
                        text: strings.timeout
        , timeout

        container = spawn 'docker', ['run', '--name', containerName, '--rm', 'node', 'bash', '-c', 'cd /home; echo ' + new Buffer(code).toString('base64') + ' | base64 --decode > ./run.js; node ./run.js']

        container.stdout.on 'data', (data) ->
            result += data.toString()

        container.stderr.on 'data', (data) ->
            result += data.toString()

        container.on 'close', (code) ->
            executionFinished = true

            if result != ""
                result += "\n"

            result += strings.end.replace /{code}/gi, code

            sendSlicedResult = (message, result, callback) ->
                bot.sendMessage
                    chat_id: message.chat.id
                    reply_to_message_id: message.message_id
                    disable_web_page_preview: true
                    text: result.slice 0, 4096
                , callback

            sliceLoop = (message, result) ->
                if result.length > 4096
                    sendSlicedResult message, result, ->
                        result = result.slice 4096
                        sliceLoop message, result
                else
                    bot.sendMessage
                        chat_id: message.chat.id
                        reply_to_message_id: message.message_id
                        disable_web_page_preview: true
                        text: result

            sliceLoop message, result
    ).start()