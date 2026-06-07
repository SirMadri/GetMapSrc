# 🗺️ GetMapSrc

> Dump and decompile every `Script` from a Roblox game - straight from your executor.

---

## 💡 What does it do?

It scans through services like `ReplicatedStorage`, `ReplicatedFirst`, and others, grabs the bytecode from every `Script`, `LocalScript` and `ModuleScript` it finds, decompiles it via the [lua.expert](https://lua.expert) API, and saves everything to your workspace folder - preserving the original folder structure.

---

## ⚡ Quick start

Execute this into your executor:

```lua
getgenv().dumper = {
    services = {
        game:GetService("ReplicatedStorage"),
    }
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/main/src/loader.luau"))()
```

Done. The script handles everything else.

---

## ⚙️ Custom config

Want to choose which services get scanned? Set `getgenv().dumper` **before** running:

```lua
getgenv().dumper = {
    services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Workspace"),
        -- add whatever you need
    },

    use_threading = true
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/main/src/loader.luau"))()
```

By default it scans `ReplicatedStorage`, `ReplicatedFirst`, `StarterPlayer`, `StarterGui` and `Workspace`.

---

## 📁 Output structure

Files get saved to your workspace like this:

```
GameName/
└── 14-30-57/
    ├── ReplicatedStorage/
    │   └── SomeModule.lua
    └── ReplicatedFirst/
        └── Loader.lua
```

---

## 🧩 Executor requirements

Your executor needs to support these APIs:

| API 
|---
| `getscriptbytecode` 
| `request` 
| `game:HttpGet` 
| `isfolder` / `makefolder` / `writefile` 
| `getgenv` 
| `cloneref` *(optional)* 

> Made by SirMadri | `sirmadrl`