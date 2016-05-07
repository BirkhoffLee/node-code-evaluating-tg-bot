spawn   = require('child_process').spawn
Bot     = require 'node-telegram-bot'
timeout = 120000 # in ms
token   = 'YOUR_TOKEN_HERE'

if !Date.now
    Date.now = -> return new Date().getTime()

console.log "Checking Docker installation & download latest node image."

spawn('docker', ['run', '--rm', 'node']).on 'close', (code) ->
    if code != 0
        console.log "Please check your Docker installation. Make sure 'docker run --rm node' can be executed normally."
        process.exit -1

    console.log "Docker installation check OK & node image has been downloaded and ready."

    bot = new Bot(
        token: token
    ).on('message', (message) ->
        console.log "@#{message.from.username}: #{message.text}"

        if !message.text?
            bot.sendMessage
                chat_id: message.chat.id,
                text: "Sorry #{message.from.first_name}! You have to give me the node.js code(in string) so I can evaluate that for you!"
            return

        if message.text.indexOf("/start") == 0
            bot.sendMessage
                chat_id: message.chat.id,
                text: "Hello #{message.from.first_name}!\nYou can tell me what node.js code I need to evaluate, and I will give you the result.\nYou can call installModule(\"module1\", \"module2\"(, ...), callback) to install npm modules and require them in the script.\nAfter " + timeout/1000 + " seconds of execution, the script will timeout and be killed."
            return

        code = 'function installModule() {\
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
                    })\
                }' + message.text

        containerName     = Date.now().toString()
        executionFinished = false
        result            = ""

        bot.sendMessage
            chat_id: message.chat.id,
            text: "** Script execution started, which its ID is #{containerName}, execution timeout is " + timeout/1000 + " seconds. The result will be sent to you after execution. (up to " + timeout/1000 + " seconds) **"

        setTimeout ->
            if !executionFinished
                spawn('docker', ['rm', '-f', containerName]).on 'close', (code) ->
                    bot.sendMessage
                        chat_id: message.chat.id,
                        text: "** Script with ID #{containerName} execution timed out, killing the script. (" + timeout/1000 + " seconds) **"
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

            bot.sendMessage
                chat_id: message.chat.id,
                text: "#{result}** Script with ID #{containerName} execution ended with code #{code} **"
    ).start()