# GetMapSrc

> Open-source Roblox script, remote & map dumper.  
> Dumps and decompiles every `LocalScript` and `ModuleScript` from a Roblox game — straight from your executor.

---

## What does it do?

- Scans services like `ReplicatedStorage`, `Workspace`, etc.
- Grabs bytecode from every `LocalScript` and `ModuleScript` and decompiles it via the [lua.expert](https://lua.expert) API
- Dumps `RemoteEvent`, `RemoteFunction` and `UnreliableRemoteEvent` metadata
- Generates `_meta.lua` files for every instance that has children, and for all `GuiObject`/`UIBase` elements (including leaf elements like buttons and labels) — preserving the full layout with `UDim2` positions, colors, text, fonts and more
- Optionally scans nil-parented instances via `getnilinstances`
- Saves everything preserving the original folder structure

---

## Quick start

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/main/src/loader.luau"))()
```

That's it. Runs with defaults and saves to your executor workspace folder.

---

## Custom config

Set `getgenv().dumper` **before** running to control behavior:

```lua
getgenv().dumper = {
    -- services to scan (default: RS, RF, StarterPlayer, StarterGui, Workspace)
    services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
        game:GetService("Workspace"),
    },

    use_threading = true,       -- parallel decompilation (faster, default: true)
    dump_remotes = true,        -- dump RemoteEvent / RemoteFunction (default: true)
    dump_map = true,            -- generate _meta.lua for instances with children (default: true)
    dump_collection = true,     -- dump CollectionService tags (default: true)
    dump_values = true,         -- dump StringValue/NumberValue/BoolValue/etc (default: true)
    dump_bindables = true,      -- dump BindableEvent / BindableFunction (default: true)
    dump_nil_instances = true,  -- scan getnilinstances() if supported (default: true)

    -- limit _meta.lua generation to specific services only (default: all services)
    -- map_services = { Workspace = true },

    -- max instances listed per CollectionService tag (default: 500, nil = unlimited)
    -- collection_max_per_tag = 500,
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/SirMadri/GetMapSrc/main/src/loader.luau"))()
```

---

## Output structure

```
_GetMapSrc/
└── GameName/
    └── 14-30-57/
        ├── Workspace/
        │   ├── Coin/
        │   │   └── _meta.lua           -- Part properties, attributes, tags, children
        │   ├── Characters/
        │   │   ├── _meta.lua           -- Folder descriptor
        │   │   └── SirMadri/
        │   │       └── _meta.lua       -- Model with WorldPivot, PrimaryPart, etc.
        │   └── CoinHandler.lua         -- decompiled LocalScript
        ├── ReplicatedStorage/
        │   └── CoinService.lua         -- decompiled ModuleScript
        ├── Remotes/
        │   └── ReplicatedStorage/
        │       └── CollectCoin.remote.lua
        ├── _CollectionService/         -- one file per tag
        │   ├── Collectible.lua         -- lists all tagged instance paths
        │   └── PlayerCharacter.lua     -- truncated if > collection_max_per_tag
        ├── StarterGui/
        │   └── MainMenu/
        │       ├── _meta.lua           -- ScreenGui (enabled, z_index_behavior)
        │       └── Background/
        │           ├── _meta.lua       -- Frame (position, size, background_color3...)
        │           ├── PlayButton/
        │           │   └── _meta.lua  -- TextButton (text, font, text_color3, UDim2...)
        │           └── QuitButton/
        │               └── _meta.lua  -- leaf GuiObject, no children needed
        ├── _Values/
        │   ├── ReplicatedStorage.lua   -- all StringValue/NumberValue/BoolValue/etc per service
        │   └── Workspace.lua
        ├── _Bindables/
        │   └── ReplicatedStorage/
        │       └── Events/
        │           ├── OnCoinCollected.lua   -- BindableEvent
        │           └── GetPlayerData.lua     -- BindableFunction
        └── nilinstances/               -- only if executor supports getnilinstances
            ├── HiddenCoinHandler.lua   -- nil-parented script
            └── HiddenFolder/
                ├── _meta.lua           -- parent = "nil"
                └── HiddenModule.lua
```

### `_meta.lua` format

```lua
return {
    name = "Coin",
    class_name = "Part",

    properties = {
        anchored = true,
        can_collide = false,
        material = "Neon",
        color = {255, 215, 0},
        size = { x = 2, y = 2, z = 2 },
        position = { x = 150, y = 10, z = 320 },
    },

    attributes = {
        coin_value = 50,
        respawn_time = 30,
    },

    tags = { "Collectible", "Coin" },

    references = {
        parent = "Workspace.Coins",
    },

    statistics = {
        descendants = 3,
        children = 3,
    },

    children = {
        "ProximityPrompt",
        "Highlight",
        "BillboardGui",
    },
}
```

See [`output_example/`](output_example/) for a full realistic example.

---

## Executor requirements

| API | Required |
|---|---|
| `getscriptbytecode` | Yes |
| `request` | Yes |
| `game:HttpGet` | Yes |
| `isfolder` / `makefolder` / `writefile` | Yes |
| `getgenv` | Yes |
| `cloneref` | No — falls back to passthrough |
| `getnilinstances` | No — nil instance scan skipped if missing |
| `base64_encode` | No — built-in fallback used |

The loader auto-detects which APIs are available via `UNC.luau` and warns you if something critical is missing.

---

> Made by SirMadri | [github.com/SirMadri/GetMapSrc](https://github.com/SirMadri/GetMapSrc)
