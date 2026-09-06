## [0.7.0](https://github.com/saghen/blink.pairs/compare/v0.6.0..v0.7.0) - 2026-09-04

### Breaking Changes

- drop `highlights.ns` option ([21c2ac9](https://github.com/saghen/blink.pairs/commit/21c2ac9164b36ae5e22f84a2dd0f02eaf107f8fe))

### Features

- support keys not contained in the pairs they expand to (#120) ([dd57684](https://github.com/saghen/blink.pairs/commit/dd57684daf1297e854e46c85511e7875efb4de75))
- add sh, zsh, bash, fish parsing (#131) ([de3f8a6](https://github.com/saghen/blink.pairs/commit/de3f8a68fef206f96bfb1d550dafe8e9d076dc49))
- bring back pairs separated by enter on the same line after backspace (#128) ([9d81008](https://github.com/saghen/blink.pairs/commit/9d81008460981beec983ad570f66f660bc39e398))
- add `systemverilog` and `verilog` (#130) ([1a4b7c0](https://github.com/saghen/blink.pairs/commit/1a4b7c0a8ae71c18fc1afc8b38213458eb9af9ba))
- add `cmake` support (#132) ([706683f](https://github.com/saghen/blink.pairs/commit/706683fcd9250aec53e700d0482aeb245dc69a63))
- support unterminiated non delimiters (#133) ([f889c4c](https://github.com/saghen/blink.pairs/commit/f889c4cbd481dc7c5b1212e228c0502832e89813))

### Bug Fixes

- only use `std::hint::cold_path` if rust is at least >= 1.95.0. (#111) ([bf30af0](https://github.com/saghen/blink.pairs/commit/bf30af06185e4e788af032a83abfa982f60d0985))
- remove outdated remove_file in build.rs ([667dc9d](https://github.com/saghen/blink.pairs/commit/667dc9dd5a3735883b0204212b9602c626ede3fe))
- fixed repro.lua (#115) ([d0f0043](https://github.com/saghen/blink.pairs/commit/d0f00431105f773ae50cdc0fa03208448f5f829e))
- use global namespace for highlight definitions (#122) ([257296f](https://github.com/saghen/blink.pairs/commit/257296f896c25d89b44f48eb2c20bcc32de3d043))
- add open, close and open_or_close field for config validation (#123) ([4ba1146](https://github.com/saghen/blink.pairs/commit/4ba1146d17a357eb479393e61ded87490dad4f90))
- verify the trigger key is the right one before expanding a pair (#127) ([2336bdf](https://github.com/saghen/blink.pairs/commit/2336bdf90446cc2d82eb897af3c9f8cbaf4074e9))

### Refactor

- support blink.lib.config api changes (#134) ([b85b422](https://github.com/saghen/blink.pairs/commit/b85b422415e6fe17003a5a8fa35795d4e128290b))

## New Contributors ❤︎

- @evanwporter made their first contribution in [#132](https://github.com/saghen/blink.pairs/pull/132)
- @antinomie8 made their first contribution in [#128](https://github.com/saghen/blink.pairs/pull/128)
- @memagu made their first contribution in [#122](https://github.com/saghen/blink.pairs/pull/122)
- @sergentbne made their first contribution in [#115](https://github.com/saghen/blink.pairs/pull/115)

## [0.6.0](https://github.com/saghen/blink.pairs/compare/v0.5.0..v0.6.0) - 2026-06-11

### Breaking Changes

- migrate to blink.lib (#103) ([c733262](https://github.com/saghen/blink.pairs/commit/c7332620980a488fd2b62452bf2dd54a05e250d2))

### Features

- *(nix)* refactor (#98) ([1e8ad76](https://github.com/saghen/blink.pairs/commit/1e8ad765ab956e87b0c7b86a32ffc5c265d9519b))
- add fennel support (#91) ([06a40fb](https://github.com/saghen/blink.pairs/commit/06a40fb64f350679d3fe741b0f19064c31c84488))
- Add '' block string mapping for nix (#95) ([342c69c](https://github.com/saghen/blink.pairs/commit/342c69c3f72c337ada9d9f523da6c61aaefd3cad))
- use fearless_simd crate, switch to stable toolchain, drop fenix (#101) ([a743a02](https://github.com/saghen/blink.pairs/commit/a743a02bc4fb17db864c5d6eb700b330c90e654b))
- adopt `blink.lib.nvim` ([d48e086](https://github.com/saghen/blink.pairs/commit/d48e086edc6af1902f250e337a3e653de6dd5c27))
- add panic hook to prevent println ([e3bfb44](https://github.com/saghen/blink.pairs/commit/e3bfb441f18864c156dc22fce852a510e1c9b767))
- merge indents/tokenize/parse, remove simd, simplify lookahead (#104) ([44ef9b9](https://github.com/saghen/blink.pairs/commit/44ef9b9eb77cd5dfca471b6f7dc0ee74888626fb))

### Bug Fixes

- *(bench)* criterion::black_box is deprecated ([9126f83](https://github.com/saghen/blink.pairs/commit/9126f83dd9c14da2712d76b5b9de14d92fcc46b1))
- *(benches)* crate name ([9d6f819](https://github.com/saghen/blink.pairs/commit/9d6f819404cbc442e4ba00b22e421f2edcde90ab))
- *(nix)* include queries in plugin ([c1fa408](https://github.com/saghen/blink.pairs/commit/c1fa4086b12560594110aa03a2fe4f6b57eddeaa))
- *(nix)* build with blink.lib ([276554f](https://github.com/saghen/blink.pairs/commit/276554fa64a6f6c3866181cc655498948184878c))
- *(nix)* disable failing require checks ([100a60c](https://github.com/saghen/blink.pairs/commit/100a60c07a1c8350ce91d048285b497c5e64b0b8))
- *(rust)* rust lifetimes quote pairing after impl< ([a1a9d16](https://github.com/saghen/blink.pairs/commit/a1a9d16b4c3ed033e2c968c28876dc64a659d5a3))
- treat " as block comment in nix ([2da33da](https://github.com/saghen/blink.pairs/commit/2da33da164fbbf5cf52214fb9e7db1096d55e0dc))
- reparse on edit boundary state change ([aab1fb8](https://github.com/saghen/blink.pairs/commit/aab1fb8dcb3582970dc0c6b74d4c41a996e2255e))
- clippy lints ([0da7048](https://github.com/saghen/blink.pairs/commit/0da7048c2393d29ddaad6a168499c5eca92c1a90))
- move debug time to after reparse ([e560220](https://github.com/saghen/blink.pairs/commit/e5602204d4a5d07a5f5bc52b73678be338b70fa2))
- rust doesn't need new_end_line ([89a56ac](https://github.com/saghen/blink.pairs/commit/89a56ac1852b00d6b00f213633e236afea0b5572))
- add /lib to gitignore ([b58f8c9](https://github.com/saghen/blink.pairs/commit/b58f8c9e2c2e962cc9e7dbf5b3c8085766368ef5))
- build on gnu toolchain instead of gnu ([2b14612](https://github.com/saghen/blink.pairs/commit/2b146125c0bfac09774d57b025fd4f4c606987d4))
- correctly resolve project_root in rust.lua (#107) ([436857a](https://github.com/saghen/blink.pairs/commit/436857a5c2558c8f66a61ce4745d1342789a4881))

### Refactor

- remove int_rounding feature ([7a2e375](https://github.com/saghen/blink.pairs/commit/7a2e375afbae3b392f5a2ee0b07f829ebb06af40))

### Documentation

- update extui to core ui2 ([b36ce7a](https://github.com/saghen/blink.pairs/commit/b36ce7a4fe53d5c0aea82b2235dd6d317367eb6c))
- add blink.lib to vim.pack.add example ([8304212](https://github.com/saghen/blink.pairs/commit/8304212d7218bf054cc96a0a55335bfe04fd0a9f))
- make version requirement for prebuilt binaries more clear ([607e1b6](https://github.com/saghen/blink.pairs/commit/607e1b6e298fbab6f12ea6e51afa7299dedc8eb1))
- misc cross.toml ([766733c](https://github.com/saghen/blink.pairs/commit/766733ca6e1567384f90cbf1b1eddf1a6318b38d))
- clarify prebuilt binary downloads ([5ff316b](https://github.com/saghen/blink.pairs/commit/5ff316b07c577f86cfb72ab2d30ce11bc27de66b))

### Performance

- send concatenated text to parser ([d4cc5a9](https://github.com/saghen/blink.pairs/commit/d4cc5a91d5f201a42fc569307e3d5d11de5ae7fc))

### Testing

- fixup broken tests ([48f3946](https://github.com/saghen/blink.pairs/commit/48f3946d938905fe09400fb100c7a96d0f546b86))

### Revert

- send concatenated text to parser ([cc1694a](https://github.com/saghen/blink.pairs/commit/cc1694aeff34bc29bd6057f8b1724abbe9f9ef53))

## New Contributors ❤︎

- @bandithedoge made their first contribution in [#91](https://github.com/saghen/blink.pairs/pull/91)

## [0.5.0](https://github.com/saghen/blink.pairs/compare/v0.4.1..v0.5.0) - 2026-03-24

### Features

- *(nix)* change plugin pname to blink.pairs ([22ded8a](https://github.com/saghen/blink.pairs/commit/22ded8a73e15ed936471ebf7a77a065570fc627b))
- *(wrap)* add reverse, treesitter, and normal mode wrapping ([eddd3b2](https://github.com/saghen/blink.pairs/commit/eddd3b25053a17460107c73deb8669e2cb6093dd))
- *(wrap)* split motion vs treesitter, rename nomovecursor to move_cursor ([5951821](https://github.com/saghen/blink.pairs/commit/59518218e6de1edc67a0f15a4dfd279cbe16904e))
- *(wrap)* rename wrap types, support backward/forward in motions ([bc0304a](https://github.com/saghen/blink.pairs/commit/bc0304afdd8137aa36372954ba93165429b5f9b1))
- *(wrap)* dot-repeatable motions ([762968f](https://github.com/saghen/blink.pairs/commit/762968f4ead3f81942bf919267beb19f4468f41a))
- *(wrap)* move cursor to end of wrapped pair for treesitter ([adf2d80](https://github.com/saghen/blink.pairs/commit/adf2d8006d19211b738245d0a56eb9bdb471f54f))
- *(wrap)* config validation ([013a0db](https://github.com/saghen/blink.pairs/commit/013a0db0da33b13215f104d0ddbe76df63bdc25a))
- *(wrap)* drop `move_cursor`, get pair in operator ([c447343](https://github.com/saghen/blink.pairs/commit/c44734317996386da0308453614441fa7d7d385b))
- ignore markdown todo items for space on `[|]` ([a08ef27](https://github.com/saghen/blink.pairs/commit/a08ef274742d66ac48f35a97ac11d8d207457b60))
- add repro.lua ([10ef021](https://github.com/saghen/blink.pairs/commit/10ef0211d0aab65f6fc345db7da7574def53b763))
- support "scheme" language (#74) ([65978aa](https://github.com/saghen/blink.pairs/commit/65978aadaf9b7d6cae59c1c51cf2b366b370546e))
- Support TOML multiline strings (#84) ([c7986ef](https://github.com/saghen/blink.pairs/commit/c7986efb702d995fa8d937c23a0bd03c9d3e92b3))
- configure highlighting immediately, without setup() call ([fd4a006](https://github.com/saghen/blink.pairs/commit/fd4a00667175bd480d8eacea7e6a406c386ae95f))
- add fast wrap mappings ([a62bb84](https://github.com/saghen/blink.pairs/commit/a62bb84fa5adec7df6faf2e11eafc03c2df0232b))
- disable in `/` and `?` in cmdline ([88842ea](https://github.com/saghen/blink.pairs/commit/88842eab296a8778a46a744e0940d4b1e911b2f6))

### Bug Fixes

- *(nix)* failing vim plugin module check ([685b27c](https://github.com/saghen/blink.pairs/commit/685b27c627cdb313b478cf9342d7809ae30c4cd7))
- *(typst)* strings cannot be defined with '' ([8e935d0](https://github.com/saghen/blink.pairs/commit/8e935d07ab6a3843565afd6a6d56456678cbf43f))
- *(wrap)* motion not recognizing backwards movement ([4095bb2](https://github.com/saghen/blink.pairs/commit/4095bb2d75a7c246e26051969e6d62d20bf9ad6f))
- overflow on `iter_to` ([574ce24](https://github.com/saghen/blink.pairs/commit/574ce24d44526a76e0b76e921a92c6737a6b3954))
- ctx not passed to mode specific functions ([2ea23a5](https://github.com/saghen/blink.pairs/commit/2ea23a5f4cb9c0505422368b3a1eeea7143d8577))
- build on nightly ([2a7cb15](https://github.com/saghen/blink.pairs/commit/2a7cb15f2c4bbbbe178ebf9f3fdae19aa6d28d39))
- allow matchparen without rainbow bracket colorization (#82) ([52306a4](https://github.com/saghen/blink.pairs/commit/52306a41ab60eddc78ccb078d8f3e72f4d65f075))
- use <c-g>U to not stop undo (#85) ([1b752e4](https://github.com/saghen/blink.pairs/commit/1b752e4d26f58a616d9394778975b6d93f9b44b7))
- respect `vim.b.pairs = false` and `disabled_filetypes` in highlighter and matchparen (#83) ([c8099ea](https://github.com/saghen/blink.pairs/commit/c8099ea7e14aac8011711a0b31b4764e1d752e0f))
- prevent index out of bounds panic in reparse_range (#76) ([262b03d](https://github.com/saghen/blink.pairs/commit/262b03d52d2763557a5261a421a639a7edba4bab))
- undo keycode ([6cdb81d](https://github.com/saghen/blink.pairs/commit/6cdb81de0f7b91d14d677721e96db1cd1801d8e9))
- require highlight module after refactor (#90) ([abb047f](https://github.com/saghen/blink.pairs/commit/abb047f0cc51b48df102cf74b7142194d2ab1e52))
- match_pair multi byte resulting in duplicate matches ([6d76df9](https://github.com/saghen/blink.pairs/commit/6d76df9af82f6be4bf8267c23e56709612941f09))

### Refactor

- move highlighting/matchparen to highlight/ ([3fdcfff](https://github.com/saghen/blink.pairs/commit/3fdcfff9d91eca6e7ddba30b3d4dfd889ffd5d9f))

### Documentation

- *(wrap)* add to readme ([fcef36c](https://github.com/saghen/blink.pairs/commit/fcef36c6cbc1d21db197bd5b741918c75a2384ea))
- *(wrap)* drop move_cursor and pair ([714e708](https://github.com/saghen/blink.pairs/commit/714e70815d290b6cca8ed1837cdc0aa6d63705d2))

### Performance

- use persistent extmarks in highlighter (#78) ([97e6727](https://github.com/saghen/blink.pairs/commit/97e672714e47a14ada29621456aa72231f706d95))

## New Contributors ❤︎

- @ShangYJQ made their first contribution in [#90](https://github.com/saghen/blink.pairs/pull/90)
- @guanghechen made their first contribution in [#76](https://github.com/saghen/blink.pairs/pull/76)
- @Kaiser-Yang made their first contribution in [#85](https://github.com/saghen/blink.pairs/pull/85)
- @tacho made their first contribution in [#84](https://github.com/saghen/blink.pairs/pull/84)
- @Bthxtly made their first contribution in [#74](https://github.com/saghen/blink.pairs/pull/74)

## [0.4.1](https://github.com/saghen/blink.pairs/compare/v0.4.0..v0.4.1) - 2025-10-29

### Revert

- drop changedtick checks in watcher ([6d363d8](https://github.com/saghen/blink.pairs/commit/6d363d845bafff26e9b48047b6e1ddb05888e1e7))

## [0.4.0](https://github.com/saghen/blink.pairs/compare/v0.3.0..v0.4.0) - 2025-10-28

### Breaking Changes

- stdlib, Context, treesitter, injections (#46) ([be61fe8](https://github.com/saghen/blink.pairs/commit/be61fe8b9d4a9e089cec07fc1803b841167c9c49))

### Features

- *(cmdline)* support cmdline mode (#48) ([8821738](https://github.com/saghen/blink.pairs/commit/8821738bbbe6bb63ac0669389e5dce917c2ea166))
- *(latex)* support `' pair (#42) ([8a4fc8a](https://github.com/saghen/blink.pairs/commit/8a4fc8af7f322670de936b52effb2de228f0a4df))
- improved erroneous field in config message ([6896d6a](https://github.com/saghen/blink.pairs/commit/6896d6a7558ce9518d9cc202f4c884c6c5346819))
- nix ([570ac7d](https://github.com/saghen/blink.pairs/commit/570ac7d0a6a3bfabfde06d54b7c2d7900a2d6eb5))
- unmatched pair detection ([86247d6](https://github.com/saghen/blink.pairs/commit/86247d6d489bb26b3a6b793e8110881703378556))
- skip mappings on unmatched pair ([6bf7fea](https://github.com/saghen/blink.pairs/commit/6bf7fea9cbbe0205acc1f5a2b6180f0f210c72df))
- support disabling open/close/open_or_close rules individually ([a9d5c34](https://github.com/saghen/blink.pairs/commit/a9d5c34c80672c4577bfa4ddb426ca244c11fdc3))
- add `vim.g.blink_pairs` and `vim.b.blink_pairs` support ([f2118c5](https://github.com/saghen/blink.pairs/commit/f2118c57dc29417c7ef4d040964bd294acfa532d))
- indent simd impl ([3def427](https://github.com/saghen/blink.pairs/commit/3def4273ae9000af9876fb1870c5eb01c813c5b6))
- `BlinkPairsMatchParen` highlight group, linked to `MatchParen` ([aad41fc](https://github.com/saghen/blink.pairs/commit/aad41fc3046050c4d415b6aa8187be7908562dcc))
- add sql parser ([0398daf](https://github.com/saghen/blink.pairs/commit/0398daf94200f2905067677d3ac159b4b305d864))
- indent aware unmatched openings (#52) ([565b4d4](https://github.com/saghen/blink.pairs/commit/565b4d48a9e29d6fb93560c2cc2db6e1307f22f0))
- fix nix build by disabling tests ([3cf0b66](https://github.com/saghen/blink.pairs/commit/3cf0b660caf266992d6c62eb1f6049c483b35409))
- support making `highlights.groups` a function ([c2d4030](https://github.com/saghen/blink.pairs/commit/c2d4030c10e6628de159cbac79a32a70ad746290))
- support treesitter language mappings ([53327ab](https://github.com/saghen/blink.pairs/commit/53327ab7aa06287010280ea81068f0690dc825f9))
- `matchparen.include_surrounding` ([e93ccdf](https://github.com/saghen/blink.pairs/commit/e93ccdfa8042afa52f35e07e678869a7f34c6d34))
- drop changedtick checks in watcher ([78d3a1f](https://github.com/saghen/blink.pairs/commit/78d3a1fd3babbf34f3ce20a01350b4fd3cdd8281))

### Bug Fixes

- *(benches)* make sure indent benches are black boxed properly ([d99d752](https://github.com/saghen/blink.pairs/commit/d99d752be1f8df50fef777cd89ad02cf9cf69682))
- *(highlight)* don't use ephemeral extmarks (#43) ([95d04ce](https://github.com/saghen/blink.pairs/commit/95d04ce524501affa98503c4d838b8c3a4f49770))
- *(highlights)* catch errors in parsing ([34e6676](https://github.com/saghen/blink.pairs/commit/34e667657804518db914810ebe91836cff0885df))
- *(types)* cmdline was not optional ([524bf76](https://github.com/saghen/blink.pairs/commit/524bf76eae437bf965319bef413ba727729792f4))
- add disabled_filetypes to partial config ([ad46843](https://github.com/saghen/blink.pairs/commit/ad468433de0c04d8baf36ee549998c3d4b5ef246))
- disable `'` in latex (#45) ([7913618](https://github.com/saghen/blink.pairs/commit/791361857b29163a21af45b85931ca71c9675c71))
- s/blink.cmp/blink.pairs ([fb8a7cb](https://github.com/saghen/blink.pairs/commit/fb8a7cbc7a65a8b6feb293ec678a6f6ed96406b6))
- ignore `'` after letter in all languages ([f59e6da](https://github.com/saghen/blink.pairs/commit/f59e6da6a07de4bcdb018038d1c17bbc0ebbd325))
- use per-buffer last_changedticks ([211274c](https://github.com/saghen/blink.pairs/commit/211274cd88aef4164b7ccd4f6e5ef523f1ee348d))
- try to expand abbreviations in mapping (#62) ([66e22e0](https://github.com/saghen/blink.pairs/commit/66e22e00b2f6ed6217abfceb53f6675f75fafe12))
- use `'` mapping when `'` found after cursor ([cb37d8a](https://github.com/saghen/blink.pairs/commit/cb37d8acfd30031084247a4f97038b05bf8501b6))
- avoid drawing while in cmdline mode ([879fb3d](https://github.com/saghen/blink.pairs/commit/879fb3d76026efd305a686bab1d34f5be67d93ee))
- abbreviations not expanded in insert mode ([64fd515](https://github.com/saghen/blink.pairs/commit/64fd5154dbe15e4712007df4e3801c2209ec09a0))

### Refactor

- *(types)* move non-partial type definitions out of `types_partial.lua` ([05afa36](https://github.com/saghen/blink.pairs/commit/05afa3611bf1fcd6afb62b11f1a58f5eb6b2d0c5))
- clean up lane width selection ([d294d6c](https://github.com/saghen/blink.pairs/commit/d294d6c559605a1f0cb23cc0b4fbd9cf41cc32af))
- use struct for parser result ([7f38dd2](https://github.com/saghen/blink.pairs/commit/7f38dd2055964860dc29a80a227b2ee237c515bc))
- make is_escaped a field on Context ([1acae69](https://github.com/saghen/blink.pairs/commit/1acae697e5ed31c4f9031b4feda4affe542106ca))

### Documentation

- or for building from source ([f93c678](https://github.com/saghen/blink.pairs/commit/f93c67847d43af89f0a90d10e1ec531d6621d62b))
- update line for mappings config ([9b990dd](https://github.com/saghen/blink.pairs/commit/9b990dd7132365ddb8c4496620b6380f6e94b3f0))
- formatting ([d70a6b3](https://github.com/saghen/blink.pairs/commit/d70a6b3f42c826d1acab27df529a04d9574c5a30))
- add cmdline options ([24dc6c6](https://github.com/saghen/blink.pairs/commit/24dc6c63b94a5a47082fca96551692e7c5063031))
- `matchparen.include_surrounding`, indent-aware matching ([f5ad152](https://github.com/saghen/blink.pairs/commit/f5ad152e8380d1bb33037efe769c50f901d04469))

### Performance

- *(indent)* replace implementation (again) ([9c2ac08](https://github.com/saghen/blink.pairs/commit/9c2ac08700f9a6950e6fa56cacbebe8bc640d881))
- *(indents)* search for newlines, lane width ([b5ed8c3](https://github.com/saghen/blink.pairs/commit/b5ed8c31cca3c8a62b12a5c8343752bdf3218d80))

## New Contributors ❤︎

- @madmaxieee made their first contribution in [#62](https://github.com/saghen/blink.pairs/pull/62)
- @phanen made their first contribution in [#48](https://github.com/saghen/blink.pairs/pull/48)
- @mathjiajia made their first contribution in [#45](https://github.com/saghen/blink.pairs/pull/45)

## [0.3.0](https://github.com/saghen/blink.pairs/compare/v0.2.0..v0.3.0) - 2025-06-13

### Breaking Changes

- add highlights, rename to BlinkPair$Color (#10) ([494d332](https://github.com/saghen/blink.pairs/commit/494d33274526e27c83e872de099bfb9dd6a9792e))
- use nightly rust ([812f8a5](https://github.com/saghen/blink.pairs/commit/812f8a526b899392522ec29c7e504b3b7488e562))

### Features

- *(highlights)* matchparen ([3d66e0f](https://github.com/saghen/blink.pairs/commit/3d66e0f202df33bf54e20dc02f0613684452ad42))
- *(markdown)* when clause for `_` on word char ([8f44c8c](https://github.com/saghen/blink.pairs/commit/8f44c8ca4e17db7a2a7d066db7002b082b50c607))
- *(nix)* use fenix for rust toolchain to allow using experimental features (#32) ([f642abf](https://github.com/saghen/blink.pairs/commit/f642abf190cb3c595b67934493d0ddffdfb957a8))
- *(rust)* when clause for lifetimes ([e6f2c7b](https://github.com/saghen/blink.pairs/commit/e6f2c7b84f7fb9650ccf750c7195413774c5ad2b))
- github issue templates (#1) ([cb21b81](https://github.com/saghen/blink.pairs/commit/cb21b810b78478e6c4f1810f83990af8ef1dcaff))
- recover from poisoned mutex, ensure splice range is valid ([53a3437](https://github.com/saghen/blink.pairs/commit/53a3437c3548283a97409455b57ef9ed0d79dea8))
- basic, likely buggy, rule system ([9fe4e26](https://github.com/saghen/blink.pairs/commit/9fe4e2668dbf8f3982afe349b535adaacdfe11e1))
- add typst to backtick pair filetypes ([bdeab45](https://github.com/saghen/blink.pairs/commit/bdeab4508fc3f91ae1383deb97da288a61168e07))
- config refactoring and validation (#7) ([7845caa](https://github.com/saghen/blink.pairs/commit/7845caace6e9c74706ee4a17e1a7ef1be7d045c6))
- allow disabling pairs by setting to `{}` (#6) ([5d42831](https://github.com/saghen/blink.pairs/commit/5d4283173ff785aff89b67f870ad722c023afd58))
- add clojure parser (#8) ([2d593c1](https://github.com/saghen/blink.pairs/commit/2d593c1e9308483b592b4540f106e89af9d99691))
- add tyspt parser ([fd40afd](https://github.com/saghen/blink.pairs/commit/fd40afd0914509ce6265c77bbaa9e6398ac10e10))
- track parsing state across incremental reparses ([6580310](https://github.com/saghen/blink.pairs/commit/6580310f9a2241ce4e28531c309e29e9bfc331ad))
- remove `row` from Match ([b90cf6f](https://github.com/saghen/blink.pairs/commit/b90cf6f5d67a05ea24397c123415d33cfe396f80))
- remove unnecessary clone ([0b95174](https://github.com/saghen/blink.pairs/commit/0b95174eb857fbaae75ab8c0fe7c11a19b4ee5fa))
- many languages (#18) ([e370ff1](https://github.com/saghen/blink.pairs/commit/e370ff149b7fa21d82ebc634dae2c135eed20668))
- avoid concatenating and splitting from/to lines/text (#19) ([2eb7741](https://github.com/saghen/blink.pairs/commit/2eb7741166aa5e8753d17d175d6336185fc36e01))
- add benchmarks ([b08c2a2](https://github.com/saghen/blink.pairs/commit/b08c2a27988c03c74778423c892804e659ac3568))
- exclude test languages from github language stats ([e2b2777](https://github.com/saghen/blink.pairs/commit/e2b277721a72e92e03506292727ca507b4429297))
- avoid copying strings ([84ac023](https://github.com/saghen/blink.pairs/commit/84ac023e112c03be76d7aedcbf8bcd405308bb65))
- don't lex rest of line when on line comment ([b70c3b0](https://github.com/saghen/blink.pairs/commit/b70c3b01241d6f491327b81df7c14daf8957ba15))
- parse character literals in rust and csharp ([07d014e](https://github.com/saghen/blink.pairs/commit/07d014ec36b727ead8e44fdfeef72e64fa5bf7f1))
- pre-allocate matches vec ([4fc3b62](https://github.com/saghen/blink.pairs/commit/4fc3b62d00a42cbefd9705e05f87a8cfe5934fbc))
- don't clone BlockStringSymmetric delimiters ([14f1929](https://github.com/saghen/blink.pairs/commit/14f1929ec02522dfa4d5b616c76220b632e6fb2a))
- intern delimiters as 'static during lexing ([ae8de24](https://github.com/saghen/blink.pairs/commit/ae8de240908552c66427b8e6857676b873fa413a))
- initial support for latex (#21) ([217532d](https://github.com/saghen/blink.pairs/commit/217532daa3cdd869e2c838ff1d6808db1bb7b4db))
- handle multiple backslashes in `is_escaped` (#24) ([403795f](https://github.com/saghen/blink.pairs/commit/403795f549910d9bc83d20c91c415bdcb23e3c66))
- add mappings enable/disable api (#27) ([493dfd0](https://github.com/saghen/blink.pairs/commit/493dfd0ddc50fe528865e0b718dffc219ca86f86))
- get matching pairs from rust ([1b384f1](https://github.com/saghen/blink.pairs/commit/1b384f119533adedc952e4e96c7caa7600740b84))
- disable `space` rules for backtick, single and double quotes ([23f1d5e](https://github.com/saghen/blink.pairs/commit/23f1d5ee1594ca059585005dcd2544803d7c2986))
- simd matcher ([23a130c](https://github.com/saghen/blink.pairs/commit/23a130c2ad22a9ab1c0439db5dc03943eac111a4))
- rework with separate tokenization and parsing stages ([2bdde60](https://github.com/saghen/blink.pairs/commit/2bdde60d3df466424ed7f7ed1ccb880f52cf6627))
- multi byte tokens ([26f7b60](https://github.com/saghen/blink.pairs/commit/26f7b6052be8d67546450fa4f18d16931e6752d6))
- cleanup tokenizer ([049d5b2](https://github.com/saghen/blink.pairs/commit/049d5b254525d7c3af7d4a1fd9ee72e9f4fdc9c6))
- return states from parser ([5821ffb](https://github.com/saghen/blink.pairs/commit/5821ffb3036acada5c6f1383992f8bb4709258b2))
- tokenize many more chars ([4e265d1](https://github.com/saghen/blink.pairs/commit/4e265d116f160fa885a1a1d5e0a864c63cf8f508))
- split matcher out of parser, add broken stack impl ([349e64c](https://github.com/saghen/blink.pairs/commit/349e64c861b92d82c83670212af8e84895164140))
- generic matchers ([e54be82](https://github.com/saghen/blink.pairs/commit/e54be8262861ed7bb4707f110fc1fab221dbf27e))
- u8 tokens, matcher macros ([ac8c48c](https://github.com/saghen/blink.pairs/commit/ac8c48ce37ec8d1909db50c7b28bd07368a33c93))
- don't ask questions ([98850f2](https://github.com/saghen/blink.pairs/commit/98850f2f8cb45d71a87c1c9b8c7e69d4da4c3440))
- support block strings ([80b3501](https://github.com/saghen/blink.pairs/commit/80b35016801efcf5e39201b15e395f0ef1f26d86))
- add rust ([598fe34](https://github.com/saghen/blink.pairs/commit/598fe3474f208cdfb67f9bf2d9e8a28d78833517))
- add remaining languages ([9f74ef9](https://github.com/saghen/blink.pairs/commit/9f74ef9e99d88df1371149db0b4a7cd6c82f0002))
- remove old parser ([29e900a](https://github.com/saghen/blink.pairs/commit/29e900a31348158ed6ec227dc803462fee715634))
- rework types, macro arm generation and lua interface ([f192f69](https://github.com/saghen/blink.pairs/commit/f192f69dbd28afb18ed9d8f0d9e1d23437332a4b))
- add tokenize benchmarks ([7775d46](https://github.com/saghen/blink.pairs/commit/7775d46141670b18d6b8c4f54a96e2d040e178b5))
- handle escaped chars in line and block strings ([e7f128f](https://github.com/saghen/blink.pairs/commit/e7f128fd2cb18a64c72a5fb3fa85af7e68ef91ca))
- choose SIMD width at build time ([2ee4ddd](https://github.com/saghen/blink.pairs/commit/2ee4ddd04014e3756bf3b908da067d93a7cc6526))
- implements basic arbitrary spans (#31) ([02184b2](https://github.com/saghen/blink.pairs/commit/02184b26d7c4df25990564fa91be1eee2c528f63))
- enable typescript, javascriptreact, and typescriptreact filetypes ([34d9509](https://github.com/saghen/blink.pairs/commit/34d950951850dc5d32001e05b65347b8d589fd6c))
- disable with `vim.g.pairs`, `vim.b.pairs` or `mappings.disabled_filetypes` ([db86320](https://github.com/saghen/blink.pairs/commit/db863207dd52c9ecec3852f4904cd4db21b496e7))

### Bug Fixes

- *(bench)* use tokenize result to avoid optimizing everything away ([ad14954](https://github.com/saghen/blink.pairs/commit/ad14954da8849bfda2b08c2f791bca857ee2ed64))
- *(latex)* support latex, tex and bib filetype (#33) ([fc905a4](https://github.com/saghen/blink.pairs/commit/fc905a47a4b44b072c7f73c5a63ffb5574f671c5))
- *(matcher)* ignore escaped prefixes for line comments (#40) ([024f69a](https://github.com/saghen/blink.pairs/commit/024f69affca6be7a3b4850495224faf0769b6f67))
- *(matchparen)* use open length when no closing length ([dcf5c1e](https://github.com/saghen/blink.pairs/commit/dcf5c1efdbbceae55fbb8f0fd63b9df9a8da75c3))
- *(nix)* use nightly toolchain for build (#37) ([ea45248](https://github.com/saghen/blink.pairs/commit/ea4524806fa32b5a1fa28861af8f158a2ca4412b))
- *(rust)* remove raw `r""` strings ([00e0a2d](https://github.com/saghen/blink.pairs/commit/00e0a2d939513faccbada2b062fb0cb277af7da5))
- `"""` and `'''` trigger condition ([f07dee0](https://github.com/saghen/blink.pairs/commit/f07dee0174b21196ba328b4ad7a5bce331f7013e))
- use when rule when filetype defined ([fa3db9b](https://github.com/saghen/blink.pairs/commit/fa3db9b788a8691f686881d301c40aa1abf8812c))
- add when rule to triple backtick ([73ebe22](https://github.com/saghen/blink.pairs/commit/73ebe224fd8943aa604fd0b9cb6ca311f86fa9bf))
- backspace removing single space ([fc83e73](https://github.com/saghen/blink.pairs/commit/fc83e732ffda037c07a7b585833c0e3c81818a04))
- is_after_cursor checking char behind cursor ([da36791](https://github.com/saghen/blink.pairs/commit/da36791a40bad5f1d730aee957bc78e406db07a3))
- blink.cmp.config.utils => blink.pairs.config.utils ([0f9dc66](https://github.com/saghen/blink.pairs/commit/0f9dc663e77bc9d2568caada95caad292fe2db51))
- resolve freeze after file content increases (#12) ([fc93e3d](https://github.com/saghen/blink.pairs/commit/fc93e3d4d736d666c09d09108b3b853af1817aea))
- readme installation miss a comma (#14) ([197d758](https://github.com/saghen/blink.pairs/commit/197d7584a72500de537388ea684ad806fc5130a0))
- symmetric block string delimiters (#16) ([0f06988](https://github.com/saghen/blink.pairs/commit/0f069883e4a4a6bc5cdd8a29a67ca88a9b8014e4))
- remove unnecessary clone ([723e4ae](https://github.com/saghen/blink.pairs/commit/723e4aedcd25684de040ea87fe4bbef939326ecf))
- rust block comment closing delimiter ([1edc7e5](https://github.com/saghen/blink.pairs/commit/1edc7e5e25660227701a0fa827b8a1583853c08a))
- handle BlockStringClose correctly ([49dd69c](https://github.com/saghen/blink.pairs/commit/49dd69c4673d34e9539c087d5b78c3cb4f5027d2))
- remove unnecessary unwrap ([51ef71a](https://github.com/saghen/blink.pairs/commit/51ef71a4157cd29823a8ba592f98fc13e96ba817))
- handle escaped newline in strings ([b0e0287](https://github.com/saghen/blink.pairs/commit/b0e02870eb3e00a4364728cac4eea179f126a2b8))
- remove unnecessary clone ([6fc191b](https://github.com/saghen/blink.pairs/commit/6fc191b76dc7a30a657d89196b98f280ffd35958))
- use regex for single-line string parsing ([6bbbd22](https://github.com/saghen/blink.pairs/commit/6bbbd227a025d04cbbc82df234cde93db3f704e4))
- correctly parse single-character strings ([ca1c57b](https://github.com/saghen/blink.pairs/commit/ca1c57b78b6227a1a30ba8e66ae35f8c9d86b5b0))
- block comment close parsing ([b40fa18](https://github.com/saghen/blink.pairs/commit/b40fa1859a45fa55c62233a242fce00f83c30862))
- close_pair moving wrong direction ([d7f2c67](https://github.com/saghen/blink.pairs/commit/d7f2c67ca998c4c3fdf27f533cfb0d9c0a6343f3))
- don't autopair in replace mode (#23) ([6a48b60](https://github.com/saghen/blink.pairs/commit/6a48b606b7e5d0598991b770e0bc7e388697ad9a))
- config requiring all match paren options ([dc8cccc](https://github.com/saghen/blink.pairs/commit/dc8cccc703bd9d9400b0f1b469bdbc831c48735f))
- serialize Option as lua nil instead of userdata ([5ab0eee](https://github.com/saghen/blink.pairs/commit/5ab0eee3d62c593d8b7f68fc9550a3b163598a98))
- types ([d765230](https://github.com/saghen/blink.pairs/commit/d76523095c8311c10de270557c881ec175ed1922))
- clear matchparen namespace on update ([e99c5d4](https://github.com/saghen/blink.pairs/commit/e99c5d4e06946590cdbde77db5ef7008db90befa))
- occasional panic when typing in define_matcher macro ([f8a4701](https://github.com/saghen/blink.pairs/commit/f8a4701e448dae715a24e570770abcbe25cdd0e8))
- multichar MatchParen ([5549644](https://github.com/saghen/blink.pairs/commit/554964403213b13e69b6813689a25fa834923222))
- don't find matches pairs for `Kind::NonPair` ([850ca26](https://github.com/saghen/blink.pairs/commit/850ca2613a4be15e2c7bea7d89f1366f0181af00))
- only `impl` some Match constructors for `cfg(test)` ([cdfd2d2](https://github.com/saghen/blink.pairs/commit/cdfd2d21f2c673c9cf01b77eef423b334df9e8fa))
- match_pair missing adjacent opening pair on closing pair ([8fee979](https://github.com/saghen/blink.pairs/commit/8fee9792acf092e4aab19aa054a7d2e4b948aa70))
- toml has ' strings ([ada6892](https://github.com/saghen/blink.pairs/commit/ada689258a49992975faa307312cbd13488a941c))
- lua block comment closing ([a57bfdd](https://github.com/saghen/blink.pairs/commit/a57bfdd9522fab770c78709a86f99c90e210f87b))

### Refactor

- drop open_pair and close_pair usage in open_or_close_pair ([5b3bd7e](https://github.com/saghen/blink.pairs/commit/5b3bd7e542338e5367f650f1fb2469166935f630))
- implement From instead of Into on tokens ([102e203](https://github.com/saghen/blink.pairs/commit/102e20304370de194fcf98a45d877f8961477973))
- parser as a state machine ([a3e9ed1](https://github.com/saghen/blink.pairs/commit/a3e9ed1778d83706a229ea972c307802d808de8f))
- have some Tokens store their slice ([8d8096a](https://github.com/saghen/blink.pairs/commit/8d8096aa19375ddc742c95edf561a2734e3f3055))
- make Token Copy ([b038f1b](https://github.com/saghen/blink.pairs/commit/b038f1b7e2634ec8745c391f4a3c095122ebe910))
- remove unwrap ([8cee1f9](https://github.com/saghen/blink.pairs/commit/8cee1f91fdd315088069094c74a4af4b9b2f8a32))
- assume matches will always be returned ([6bd2a96](https://github.com/saghen/blink.pairs/commit/6bd2a96be55a287cf535397f10646a182efeb241))
- use `nvim_buf_line_count` instead of `vim.api.nvim_buf_get_lines` ([211a99a](https://github.com/saghen/blink.pairs/commit/211a99a8bbe9839599713e631380eb0c894ec394))

### Documentation

- update readme config ([48ea477](https://github.com/saghen/blink.pairs/commit/48ea477fafb110883ee0adcb9f3e6465499d7c63))
- add behavior to readme ([980bb16](https://github.com/saghen/blink.pairs/commit/980bb1636807606626b084e4530c3c49b420456d))
- fix markdown rendering ([b347cf9](https://github.com/saghen/blink.pairs/commit/b347cf9c30860808070f51d89898d068b2018f05))
- link to roadmap ([017fd8a](https://github.com/saghen/blink.pairs/commit/017fd8a5715205e1a9e0397178ba9077d8799831))
- simplify installation, drop pair configs ([e8fd320](https://github.com/saghen/blink.pairs/commit/e8fd3207ecec48e590651c18304b19102e5cef99))
- *speeed* ([776901e](https://github.com/saghen/blink.pairs/commit/776901e8b7c714a3fc9d727b96f337db0116b44b))
- correct readme build instruction (#35) ([ddddba3](https://github.com/saghen/blink.pairs/commit/ddddba3bd1d4df37251a82ac968bc654bac5c029))

### Performance

- don't allocate a Vec for tokens ([2719f64](https://github.com/saghen/blink.pairs/commit/2719f64df602a11f87ea94e8e5b0193b3c7ebc8b))
- splat SimdVec inside hot loop ([d4a47f7](https://github.com/saghen/blink.pairs/commit/d4a47f714821ac442af0631c5242c64e6da430e8))
- optimized release/bench build flags ([4225f60](https://github.com/saghen/blink.pairs/commit/4225f60642da74a3880f15354f4ba0546a053c04))

## New Contributors ❤︎

- @MrZLeo made their first contribution in [#40](https://github.com/saghen/blink.pairs/pull/40)
- @datsfilipe made their first contribution in [#35](https://github.com/saghen/blink.pairs/pull/35)
- @xarvex made their first contribution in [#37](https://github.com/saghen/blink.pairs/pull/37)
- @stefanboca made their first contribution
- @ph1losof made their first contribution in [#31](https://github.com/saghen/blink.pairs/pull/31)
- @redxtech made their first contribution in [#32](https://github.com/saghen/blink.pairs/pull/32)
- @xcdnlgd made their first contribution in [#27](https://github.com/saghen/blink.pairs/pull/27)
- @jinzhongjia made their first contribution in [#14](https://github.com/saghen/blink.pairs/pull/14)
- @Peeeaje made their first contribution in [#12](https://github.com/saghen/blink.pairs/pull/12)

## [0.2.0](https://github.com/saghen/blink.pairs/compare/v0.1.0..v0.2.0) - 2025-03-15

### Features

- add json parser ([04054a1](https://github.com/saghen/blink.pairs/commit/04054a12444eb6605467c50f4ae21315bbc8b407))
- auto pairs support ([0afc7bb](https://github.com/saghen/blink.pairs/commit/0afc7bb0f756a93dc65647634a2202652a46a5e2))
- escaped and space mappings ([3438406](https://github.com/saghen/blink.pairs/commit/3438406fc1cfb9a3ada5c46b1c408faf49e9e29c))
- remove `<` from default config ([d287879](https://github.com/saghen/blink.pairs/commit/d287879f4763a5e04391088e5d7266b949277c25))

### Documentation

- fix speed in readme ([f539acb](https://github.com/saghen/blink.pairs/commit/f539acbe938c51aba4497300747bbf41b6eece39))
- update descriptions for auto-pairs ([7b550c8](https://github.com/saghen/blink.pairs/commit/7b550c87ca02561dc7e77a2cfe5d3cea87376858))

## [0.1.0] - 2025-03-14

### Features

- initial commit :crab: ([ea68397](https://github.com/saghen/blink.pairs/commit/ea6839761ae64eecebe191363760812bb9a31824))
- switch from nvim-oxi to mlua ([1b1183a](https://github.com/saghen/blink.pairs/commit/1b1183ad661b4379f5d89c6b4ab1339a8cfc1bb1))
- add nix flake ([5f0408d](https://github.com/saghen/blink.pairs/commit/5f0408d7ca9fc6aff9089b2ec74d34d35c129557))
- switch ci to rust stable ([5af2afc](https://github.com/saghen/blink.pairs/commit/5af2afc1282e687ffd50485b58fe6dc718ac26f0))

### Bug Fixes

- remaining references to blink.delimiters ([7ca329b](https://github.com/saghen/blink.pairs/commit/7ca329bf9a99fc35437975ab1515f81d82086fc2))
- incremental update ranges ([2b8cbaa](https://github.com/saghen/blink.pairs/commit/2b8cbaa40755966b64eaaf1d4e1487bc7e0140fe))
- ci workflow artifact name ([cdc1a4c](https://github.com/saghen/blink.pairs/commit/cdc1a4c56e2940624a9581722fcbf5d7c5995079))
- root dir for download ([3881f52](https://github.com/saghen/blink.pairs/commit/3881f5235c1f1c4d66c6acea1c46cea66c7b874a))
- root_dir passed incorrectly ([fa8974e](https://github.com/saghen/blink.pairs/commit/fa8974e771f62e52884ccdfe1c5d5ecaacf2e72b))

### Documentation

- readme ([caf646c](https://github.com/saghen/blink.pairs/commit/caf646c3b755d232540b2dfe936769b4f7027caa))
- change TBD to TODO ([6f3f3d4](https://github.com/saghen/blink.pairs/commit/6f3f3d422babba5388522f2f4b55337c8b7f672d))

## New Contributors ❤︎

- @saghen made their first contribution

