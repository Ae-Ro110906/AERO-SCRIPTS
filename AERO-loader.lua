-- Aero Scripts Hub Intro Loader Template
local StarterGui = game:GetService("StarterGui")

-- Send a clean loading notification box into the bottom corner
StarterGui:SetCore("SendNotification", {
    Title = "Aero Scripts",
    Text = "Authenticating client data... Please wait.",
    Duration = 5
})

task.wait(1)

-- Safely download and run your massive Main script file using the instant proxy bypass
loadstring(game:HttpGet("https://githack.com"))()

StarterGui:SetCore("SendNotification", {
    Title = "Aero Scripts",
    Text = "Framework successfully executed!",
    Duration = 3
})
