# Node Code Evaluating TG Bot
A Telegram bot for executing node.js code and giving the results to users.  
Full node.js code executing support. Using Docker for virtualization & isolation.  
You will have Docker be installed, and Docker daemon be running.  
Before starting the bot, please replace YOUR_TOKEN_HERE with your Telegram bot token.  

# Demonstration
Add [@nodeCodeEvaluatingBot](https://telegram.me/nodeCodeEvaluatingBot) now!

# What Can I Do
Dynamic NPM module installing via this code:
```
installModule("module1", "module2", "module3"(, ...), callback);
```

# Warning
The Docker container will be killed and removed in 120 seconds by default.  
You can change this manually.
