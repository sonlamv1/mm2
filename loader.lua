if getgenv().config["Limit"] == "65" then
  print("loading 65")
  repeat wait()spawn(function()loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/8baf7fd6481869f96511c27da36c8f24.lua"))()end)wait(20)until getgenv().ScriptLoad
elseif getgenv().config["Limit"] == "650" then
  print("loading 650")
  repeat wait()spawn(function()loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/4d9ab21eada6d8a5bd1dc86e0ee27c17.lua"))()end)wait(20)until getgenv().ScriptLoad
elseif getgenv().config["Limit"] == "1300" then
  print("loading 650")
  repeat wait()spawn(function()loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/62275cf17bba36b6eaa2cacd1afc9ebd.lua"))()end)wait(20)until getgenv().ScriptLoad
elseif getgenv().config["Limit"] == "3750" then
  print("loading 3750")
  repeat wait()spawn(function()loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/ba54fe540babe24a5ce250bc89a1c45c.lua"))()end)wait(20)until getgenv().ScriptLoad
end
