# cambios

## quito nanocoder

flake.nix
```nix
    nanocoder = {
      url = "github:Nano-Collective/nanocoder";
    };  
```

config.nix
```nix
    inputs.nanocoder.packages."${system}".default
``` 


