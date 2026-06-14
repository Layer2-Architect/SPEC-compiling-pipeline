# 言語別ガイド: C# / .NET

このドキュメントは C# (.NET) で SCP を運用するときの DD / TC / SRC の規律をまとめる。
WPF / WinForms / ASP.NET / コンソールいずれも適用可。UI 層は非決定論層として扱う（→ §3）。

## 1. プロジェクト構成

```
.
├── MyProj.sln
├── .trace-engine.toml
├── CLAUDE.md
├── docs/...
├── scripts/trace-check.sh
├── src/
│   ├── MyProj.Core/            # 決定論層（ドメイン）
│   │   └── *.cs                // Document ID: SRC-<AREA>-NNN
│   ├── MyProj.UI/              # 非決定論層（WPF/WinForms 等）
│   └── MyProj.Infrastructure/  # 永続化・外部 API 等
├── tests/
│   └── *.cs                    // Document ID: TC-<AREA>-NNN
└── bench/                      // BenchmarkDotNet
```

`.trace-engine.toml`:

```toml
[id.types.TC]
dir = "tests/"
ext = ".cs"
file_pattern = "contains"

[id.types.SRC]
dir = "src/"
ext = ".cs"
file_pattern = "contains"
```

## 2. .csproj の最小構成

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <Nullable>enable</Nullable>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <AnalysisLevel>latest-recommended</AnalysisLevel>
  <EnableNETAnalyzers>true</EnableNETAnalyzers>
  <ImplicitUsings>enable</ImplicitUsings>
</PropertyGroup>
```

`Nullable: enable` は必須。null 参照を型レベルで管理する SCP の規律と合致する。

## 3. DD の決定論層特有事項

### 型レベル invariant

- `record` で immutable 値型
- `readonly struct` で値型 + immutability
- enum で状態の網羅性

```csharp
public readonly record struct UserId(string Value);
public readonly record struct OrderId(string Value);

public sealed record User(UserId Id, string Name, UserRole Role);

public enum UserRole { Admin, Member, Guest }
```

### Discriminated union（C# 12 では言語標準なし、OneOf 等のライブラリで代替）

```csharp
// OneOf を使う例
public OneOf<Loaded, Error> LoadResult(string id)
{
    var data = ...;
    if (data is null) return new Error("not found");
    return new Loaded(data);
}
```

または abstract record:

```csharp
public abstract record State;
public sealed record Idle() : State;
public sealed record Loading() : State;
public sealed record Loaded(Data Data) : State;
public sealed record Failed(AppError Error) : State;
```

### Result 型

LanguageExt や FluentResults の Result 型を採用する、または自前:

```csharp
public readonly record struct Result<T, E>(bool IsOk, T? Value, E? Error)
{
    public bool IsErr => !IsOk;
    public static Result<T, E> Ok(T v) => new(true, v, default);
    public static Result<T, E> Err(E e) => new(false, default, e);
}
```

### エラー型

例外を使う方針でも、公開 API では発生しうる例外を XML doc で明示:

```csharp
/// <summary>...</summary>
/// <exception cref="NotFoundException">...</exception>
/// <exception cref="ValidationException">...</exception>
public Result<Order, OrderError> CreateOrder(CreateOrderRequest req) { ... }
```

## 4. 非決定論層（WPF / UI）特有事項

### MVVM の規律

- ViewModel は View に依存しない
- Binding 方向を DD で明示（OneWay / TwoWay / OneTime）
- `INotifyPropertyChanged` の伝播範囲を限定
- `ICommand.CanExecute` は副作用を持たない（query only）

### 非同期処理

- `async/await` の境界を ViewModel に閉じる
- `ConfigureAwait(false)` を使う（UI スレッドに戻る必要がある場所のみ true）
- `IProgress<T>` で進捗通知
- `CancellationToken` を境界で受け取る

### 例

```csharp
public class OrderViewModel : INotifyPropertyChanged
{
    private readonly IOrderService _service;

    public IAsyncRelayCommand SubmitCommand { get; }

    public OrderViewModel(IOrderService service)
    {
        _service = service;
        SubmitCommand = new AsyncRelayCommand(SubmitAsync, CanSubmit);
    }

    private bool CanSubmit() => !string.IsNullOrEmpty(Title);

    private async Task SubmitAsync(CancellationToken ct)
    {
        IsBusy = true;
        try
        {
            var result = await _service.CreateAsync(...).ConfigureAwait(true);
            // UI スレッドに戻って状態更新
        }
        finally { IsBusy = false; }
    }
}
```

## 5. TC の規律（xUnit + FsCheck / FluentAssertions）

```csharp
// tests/StateTests.cs
// Document ID: TC-<AREA>-001
// 親 TS: TS-<AREA>-001

using FluentAssertions;
using FsCheck;
using FsCheck.Xunit;
using Xunit;

public class StateTests
{
    [Fact]
    public void Add_ToEmpty_ReturnsFirstId()
    {
        // @ts: TS-<AREA>-001 ケース 1
        var s = new State();
        var result = s.Add(SampleItem());
        result.IsOk.Should().BeTrue();
        result.Value.Should().Be(1);
        s.Count.Should().Be(1);
    }

    [Property]
    public Property Count_IsMonotonic(Item[] items)
    {
        // @ts: TS-<AREA>-001 ケース 3 (property)
        var s = new State();
        var prev = 0;
        foreach (var it in items)
        {
            s.Add(it);
            if (s.Count < prev) return false.ToProperty();
            prev = s.Count;
        }
        return true.ToProperty();
    }
}
```

### モック方針

- 内部依存はモック禁止（型と Result で表現）
- 外部依存は interface 化、Moq / NSubstitute は限定使用
- TestHost / WebApplicationFactory（ASP.NET）で integration test

## 6. SRC の規律

### 必須

- ファイル先頭に `// Document ID: SRC-<AREA>-NNN`
- `Nullable: enable` 必須
- 公開関数の参照型パラメータは null チェックを型レベルで（`T?` か `T` を明示）
- `TreatWarningsAsErrors: true` で warning を blocker 化

### 推奨

- `record` / `readonly struct` で immutability
- `sealed` を default に（継承を意図しないなら sealed）
- 公開 API には XML doc + cref / paramref
- `Span<T>` / `ReadOnlySpan<T>` を性能 critical な箇所で活用
- async は `Task<Result<T, E>>` を返す

### IDisposable / using

- リソース所有を明示（`using` / `using var`）
- `IAsyncDisposable` も同様
- `IDisposable` を返す関数は名前で明示（`CreateXxx` / `OpenXxx`）

## 7. CI 構成

```yaml
- name: Setup .NET
  uses: actions/setup-dotnet@v4

- name: Restore
  run: dotnet restore

- name: Build
  run: dotnet build --no-restore --warnaserror

- name: Test
  run: dotnet test --no-build --logger trx

- name: Format
  run: dotnet format --verify-no-changes

- name: Trace integrity
  run: bash scripts/trace-check.sh
```

## 8. NFR の測定

| NFR カテゴリ | 推奨ツール |
|---|---|
| 性能（latency / throughput）| BenchmarkDotNet |
| メモリ | dotMemory / PerfView |
| プロファイル | dotTrace / PerfView |
| 並行性 | （Test framework + Stress テスト）|
| 起動時間 | crossgen2 / R2R / AOT |

## 9. ありがちな落とし穴

- **null 参照例外**: `Nullable` 有効化 + `?` の明示で防ぐ
- **`async void`**: コマンドハンドラ以外で禁止（例外が握り潰される）
- **`ConfigureAwait(false)` 漏れ**: ライブラリコードで必ず付ける
- **`Task.Result` / `Task.Wait()`**: deadlock のリスク。常に `await`
- **過度な継承**: composition over inheritance、interface 中心
- **静的状態**: テスト容易性が崩れる。DI / scoped lifetime
- **`Dictionary<,>` の thread safety**: 並行アクセスは `ConcurrentDictionary` か lock

## 10. ハードルール再掲（C# 視点）

- **テストが通らない実装はマージしない**（dotnet test pass）
- **境界 API は DD で凍結**（公開 API surface を変更しない、binary compat を保つ）
- **`Document ID:` 行の必置**
- **`Nullable: enable` + warning ゼロ**
