---
name: sakura-cloud-iaas
description: |
  Sakura Cloud IaaS API (iaas-api-go) ライブラリの使用ガイド。
  さくらインターネットのクラウドサービスで、サーバー、ディスク、スイッチ、ロードバランサーなどのIaaSリソースをGoで操作する際に使用。
  リソースの作成・取得・更新・削除、電源操作、検索・フィルタリング、エラーハンドリング、フェイクモードでのテストについてガイドする。
  ユーザーが「さくらクラウド」「Sakura Cloud」「IaaS」「サーバー作成」「スイッチ作成」「ディスク作成」「リソース管理」「電源操作」「リソース検索」「APIクライアント」「Goでさくら」などの言葉を使ったら、このスキルを参照すること。
---

# Sakura Cloud IaaS API (iaas-api-go) Skill

## Overview

このスキルは、さくらクラウドのIaaSサービスをGoから操作するための `iaas-api-go` ライブラリの使い方を提供します。

このライブラリを使用する際は：
1. **クライアント初期化** - APIトークンを使用してクライアントを作成
2. **リソースオペレーション** - オペレーションを作成して操作対象を選択
3. **CRUD操作** - 作成・取得・更新・削除を実行
4. **検索** - フィルタリングとソートでリソースを検索
5. **エラーハンドリング** - APIエラーを適切に処理

## クライアント初期化

### 基本的な方法

APIトークンを直接使用する場合：

```go
package main

import (
    "context"
    "github.com/sacloud/iaas-api-go"
)

func main() {
    ctx := context.Background()
    
    // 環境変数から読み込み
    client := iaas.NewClientFromEnv()
    
    // または直接指定
    client := iaas.NewClient(token, secret)
}
```

**環境変数：**
- `SAKURACLOUD_ACCESS_TOKEN` - APIアクセストークン
- `SAKURACLOUD_ACCESS_TOKEN_SECRET` - シークレット

### helper/apiパッケージを使用（推奨）

より高度な設定が必要な場合：

```go
import (
    "github.com/sacloud/api-client-go"
    "github.com/sacloud/iaas-api-go/helper/api"
)

// 環境変数・プロファイルから自動設定
opts, err := api.DefaultOption()
if err != nil {
    log.Fatal(err)
}
caller := api.NewCallerWithOptions(opts)

// カスタムオプション
opts := &api.CallerOptions{
    Options: &client.Options{
        AccessToken:       token,
        AccessTokenSecret: secret,
    },
    DefaultZone: "is1a",
    TraceAPI:    true,  // API呼び出しをトレース
}
caller := api.NewCallerWithOptions(opts)
```

## リソース操作パターン

多くのリソースで共通のCRUDパターンが使用されます：

```go
// 1. オペレーション（Op）を作成
resourceOp := iaas.NewXxxOp(client)

// 2. メソッドを呼び出し（リソースにより利用可能なメソッドは異なる）
result, err := resourceOp.Create(ctx, zone, request)    // 作成
result, err := resourceOp.Read(ctx, zone, id)           // 取得
result, err := resourceOp.Update(ctx, zone, id, request) // 更新
err := resourceOp.Delete(ctx, zone, id)                 // 削除
result, err := resourceOp.Find(ctx, zone, condition)    // 検索
```

### 操作パターンの種類

**1. フルCRUD（作成・取得・更新・削除）**
Server, Disk, Switch, Internet, LoadBalancer, VPCRouter, Database, Archive, SSHKey など

**2. 読み取り専用（検索・取得のみ）**
Zone, Region, ServerPlan, DiskPlan, LicenseInfo, PrivateHostPlan など

**3. 設定のみ更新（UpdateSettings）**
AutoBackup, DNS, GSLB, SimpleMonitor などは設定のみを更新

**4. アプライアンス特有（電源操作付き）**
Database, LoadBalancer, VPCRouter, NFS などは Boot/Shutdown/Reset を持つ

**5. 特殊操作**
Bill（請求）, AuthStatus（認証）, Coupon（クーポン）などは専用メソッド

**利用可能なオペレーション：**

**コンピューティング:**
- `NewServerOp()` - サーバー
- `NewServerPlanOp()` - サーバープラン
- `NewPrivateHostOp()` - 専有ホスト
- `NewPrivateHostPlanOp()` - 専有ホストプラン

**ストレージ:**
- `NewDiskOp()` - ディスク
- `NewDiskPlanOp()` - ディスクプラン
- `NewArchiveOp()` - アーカイブ/ISOイメージ
- `NewCDROMOp()` - CD-ROM

**ネットワーク:**
- `NewSwitchOp()` - スイッチ
- `NewInternetOp()` - ルーター
- `NewInternetPlanOp()` - インターネットプラン
- `NewInterfaceOp()` - ネットワークインターフェース
- `NewSubnetOp()` - サブネット
- `NewBridgeOp()` - ブリッジ
- `NewIPAddressOp()` - IPアドレス
- `NewIPv6NetOp()` - IPv6ネット
- `NewIPv6AddrOp()` - IPv6アドレス
- `NewPacketFilterOp()` - パケットフィルタ

**アプライアンス:**
- `NewLoadBalancerOp()` - ロードバランサー
- `NewVPCRouterOp()` - VPCルーター
- `NewDatabaseOp()` - データベース
- `NewNFSOp()` - NFS
- `NewNASOp()` - NAS
- `NewMobileGatewayOp()` - モバイルゲートウェイ

**DNS/アクセス制御:**
- `NewDNSOp()` - DNS
- `NewGSLBOp()` - GSLB
- `NewSimpleMonitorOp()` - シンプル監視

**認証/セキュリティ:**
- `NewSSHKeyOp()` - SSH鍵
- `NewCertificateAuthorityOp()` - 証明書認証局
- `NewLicenseOp()` - ライセンス
- `NewLicenseInfoOp()` - ライセンス情報

**コンテナ/レジストリ:**
- `NewContainerRegistryOp()` - コンテナレジストリ

**自動化:**
- `NewAutoScaleOp()` - オートスケール
- `NewAutoBackupOp()` - 自動バックアップ
- `NewESMEOp()` - ESME（SMS送信）

**通知:**
- `NewSimpleNotificationDestinationOp()` - シンプル通知宛先
- `NewSimpleNotificationGroupOp()` - シンプル通知グループ

**その他:**
- `NewIconOp()` - アイコン
- `NewNoteOp()` - スタートアップスクリプト
- `NewProxyLBOp()` - エンハンスドロードバランサー
- `NewLocalRouterOp()` - ローカルルーター
- `NewEnhancedDBOp()` - エンハンスドデータベース
- `NewSIMOp()` - SIM
- `NewBillOp()` - 請求
- `NewCouponOp()` - クーポン
- `NewServiceClassOp()` - サービスクラス
- `NewZoneOp()` - ゾーン
- `NewRegionOp()` - リージョン
- `NewAuthStatusOp()` - 認証ステータス

## リソースの作成

各リソースには専用のCreateRequest構造体があります：

```go
// スイッチ作成
sw, err := iaas.NewSwitchOp(client).Create(ctx, "is1a", &iaas.SwitchCreateRequest{
    Name:        "my-switch",
    Description: "説明",
    Tags:        types.Tags{"env:prod", "app:web"},
})

// サーバー作成
server, err := iaas.NewServerOp(client).Create(ctx, "is1a", &iaas.ServerCreateRequest{
    CPU:               1,
    MemoryMB:          1024,
    Commitment:        types.Commitments.Standard,
    Generation:        types.PlanGenerations.Default,
    ConnectedSwitches: []*iaas.ConnectedSwitch{},
    InterfaceDriver:   types.InterfaceDrivers.VirtIO,
    Name:              "my-server",
    Description:       "説明",
})

// ディスク作成
disk, err := iaas.NewDiskOp(client).Create(ctx, "is1a", &iaas.DiskCreateRequest{
    Name:            "my-disk",
    SizeMB:          20 * 1024 * 1024, // 20GB
    DiskPlanID:      types.DiskPlans.SSD,
    Connection:      types.DiskConnections.VirtIO,
}, nil, 0)
```

## リソースの取得と更新

```go
// 単一リソースの取得
server, err := iaas.NewServerOp(client).Read(ctx, "is1a", serverID)

// 更新
server, err = iaas.NewServerOp(client).Update(ctx, "is1a", serverID, &iaas.ServerUpdateRequest{
    Name:        "my-server-renamed",
    Description: "更新された説明",
    Tags:        types.Tags{"tag1"},
})
```

## リソースの一覧と検索

FindConditionを使用して検索・フィルタリング：

```go
import (
    "github.com/sacloud/iaas-api-go"
    "github.com/sacloud/iaas-api-go/search"
)

// 基本検索
result, err := iaas.NewServerOp(client).Find(ctx, "is1a", nil)

// フィルタリング
condition := &iaas.FindCondition{
    Filter: search.Filter{
        // 部分一致
        search.Key("Name"): search.PartialMatch("example"),
        
        // 完全一致
        search.Key("Tags"): search.AndEqual("production"),
        
        // OR条件
        search.Key("Zone.Name"): search.OrEqual("is1a", "is1b"),
    },
    Count: 20, // 最大20件
    From:  0,  // オフセット
    Sort:  search.SortKeys{{Key: "CreatedAt", Order: search.SortDesc}},
}

result, err := iaas.NewServerOp(client).Find(ctx, "is1a", condition)
for _, server := range result.Servers {
    fmt.Printf("Server: %s (ID: %d)\n", server.Name, server.ID)
}
```

**検索フィルタ：**
- `search.PartialMatch(str)` - 部分一致
- `search.OrEqual(val1, val2...)` - いずれかに一致
- `search.AndEqual(val1, val2...)` - すべてに一致
- `search.KeyWithOp(key, search.OpLessThan)` - 数値比較（<, >, <=, >=）

## リソースの削除

```go
err := iaas.NewServerOp(client).Delete(ctx, "is1a", serverID)
```

## 電源操作

ヘルパーパッケージを使用：

```go
import "github.com/sacloud/iaas-api-go/helper/power"

// 起動
err = power.BootServer(ctx, serverOp, "is1a", serverID)

// シャットダウン（force=trueで強制停止）
err = power.ShutdownServer(ctx, serverOp, "is1a", serverID, true)
```

**利用可能な電源操作：**
- `power.BootServer()` / `power.ShutdownServer()` - サーバー
- `power.BootLoadBalancer()` / `power.ShutdownLoadBalancer()` - ロードバランサー
- `power.BootDatabase()` / `power.ShutdownDatabase()` - データベース
- `power.BootVPCRouter()` / `power.ShutdownVPCRouter()` - VPCルーター
- `power.BootNFS()` / `power.ShutdownNFS()` - NFS
- `power.BootMobileGateway()` / `power.ShutdownMobileGateway()` - モバイルゲートウェイ

## 待機処理

リソースの準備ができるまで待機：

```go
import "github.com/sacloud/iaas-api-go/helper/wait"

// サーバーが起動するまで待機
server, err := wait.UntilServerIsUp(ctx, serverOp, "is1a", serverID)

// ディスクの準備待ち
disk, err := wait.UntilDiskIsReady(ctx, diskOp, "is1a", diskID)

// データベースの起動待ち
db, err := wait.UntilDatabaseIsUp(ctx, dbOp, "is1a", dbID)

// VPCルーターの準備待ち
router, err := wait.UntilVPCRouterIsUp(ctx, routerOp, "is1a", routerID)
```

## エラーハンドリング

```go
// 404判定
if iaas.IsNotFoundError(err) {
    // リソースが存在しない
}

// 検索結果なし判定
if iaas.IsNoResultsError(err) {
    // 検索で結果が見つからない
}

// 状態待機エラー
if iaas.IsStillCreatingError(err) {
    // リソース作成中
}

// 詳細なエラー情報
if apiErr, ok := err.(iaas.APIError); ok {
    responseCode := apiErr.ResponseCode()
    errorCode := apiErr.Code()
    message := apiErr.Message()
}
```

## フェイクモード（テスト）

実際のさくらクラウドAPIを呼び出さずにテストするためのモックモードです。テストや開発時に使用します。

### FakeModeとは

FakeModeでは：
- 実際のAPIサーバーには通信しません
- メモリ上でデータを管理します（デフォルト）
- 必要に応じてファイルに永続化可能です
- すべてのAPI操作が即座に完了します（待機不要）
- IDはFakeMode内部で自動採番されます

### 基本的な使い方

```go
import (
    "github.com/sacloud/api-client-go"
    "github.com/sacloud/iaas-api-go/helper/api"
)

// FakeModeで初期化
opts := &api.CallerOptions{
    Options: &client.Options{
        AccessToken:       "dummy",  // ダミー値でOK
        AccessTokenSecret: "dummy",
    },
    FakeMode: true,
}
caller := api.NewCallerWithOptions(opts)

// 通常通りのAPI操作（実際のAPIは呼ばれない）
serverOp := iaas.NewServerOp(caller)
server, err := serverOp.Create(ctx, "is1a", &iaas.ServerCreateRequest{
    CPU:               1,
    MemoryMB:          1024,
    Name:              "test-server",
    Commitment:        types.Commitments.Standard,
    Generation:        types.PlanGenerations.Default,
    ConnectedSwitches: []*iaas.ConnectedSwitch{},
})
// IDは自動採番される（例: 100000000001）
fmt.Printf("Created server with ID: %d\n", server.ID)
```

### ファイル永続化（オプション）

テストデータをファイルに保存する場合は`FakeStorePath`を指定します：

```go
opts := &api.CallerOptions{
    Options: &client.Options{
        AccessToken:       "dummy",
        AccessTokenSecret: "dummy",
    },
    FakeMode:      true,
    FakeStorePath: "/tmp/my-fake-store.json",
}
caller := api.NewCallerWithOptions(opts)

// 操作したデータが自動的にJSONファイルに保存される
server, err := iaas.NewServerOp(caller).Create(ctx, "is1a", &iaas.ServerCreateRequest{...})
```

**注意：** `FakeStorePath`を使用すると、DataStoreがグローバルに変更されます。テスト間でデータを共有する場合は、同じ`caller`インスタンスを使用するか、ファイルを明示的に読み込み直してください。

### 実践的なテスト例

```go
package main

import (
    "context"
    "fmt"
    "testing"
    
    "github.com/sacloud/api-client-go"
    "github.com/sacloud/iaas-api-go"
    "github.com/sacloud/iaas-api-go/helper/api"
    "github.com/sacloud/iaas-api-go/helper/power"
    "github.com/sacloud/iaas-api-go/types"
)

func TestServerLifecycle(t *testing.T) {
    ctx := context.Background()
    
    // FakeModeでクライアント初期化
    caller := api.NewCallerWithOptions(&api.CallerOptions{
        Options: &client.Options{
            AccessToken:       "test",
            AccessTokenSecret: "test",
        },
        FakeMode: true,
    })
    
    serverOp := iaas.NewServerOp(caller)
    
    // 作成
    server, err := serverOp.Create(ctx, "is1a", &iaas.ServerCreateRequest{
        CPU:               1,
        MemoryMB:          1024,
        Name:              "test-server",
        Commitment:        types.Commitments.Standard,
        Generation:        types.PlanGenerations.Default,
        ConnectedSwitches: []*iaas.ConnectedSwitch{},
    })
    if err != nil {
        t.Fatalf("Failed to create server: %v", err)
    }
    t.Logf("Created server: ID=%d, Name=%s", server.ID, server.Name)
    
    // FakeModeでは即座に起動可能
    if err := power.BootServer(ctx, serverOp, "is1a", server.ID); err != nil {
        t.Fatalf("Failed to boot server: %v", err)
    }
    
    // 状態確認
    server, _ = serverOp.Read(ctx, "is1a", server.ID)
    if server.InstanceStatus != types.ServerInstanceStatuses.Up {
        t.Errorf("Server should be up, got %s", server.InstanceStatus)
    }
    
    // 停止（削除前に停止が必要）
    if err := power.ShutdownServer(ctx, serverOp, "is1a", server.ID, true); err != nil {
        t.Fatalf("Failed to shutdown server: %v", err)
    }
    
    // 削除
    if err := serverOp.Delete(ctx, "is1a", server.ID); err != nil {
        t.Fatalf("Failed to delete server: %v", err)
    }
    
    // 存在確認
    _, err = serverOp.Read(ctx, "is1a", server.ID)
    if !iaas.IsNotFoundError(err) {
        t.Errorf("Expected NotFoundError after delete, got: %v", err)
    }
    t.Log("Server deleted successfully")
}
```

### FakeModeの特徴と注意点

**メリット：**
- ネットワークに依存せず、高速にテストできる
- 実際のAPI利用料金がかからない
- 副作用なしでCRUD操作を試せる

**注意点：**
- **AccessToken/Secretは必須**：FakeModeでも`CallerOptions.Options`にダミー値を設定する必要があります
- **データは分離される**：デフォルトではテスト間でデータは共有されません
- **一部の機能制限**：実際のネットワーク接続検証などはできません

### テストユーティリティとの組み合わせ

```go
// テストヘルパー関数
func NewFakeCaller(t *testing.T) iaas.APICaller {
    t.Helper()
    return api.NewCallerWithOptions(&api.CallerOptions{
        Options: &client.Options{
            AccessToken:       "fake-test",
            AccessTokenSecret: "fake-test",
        },
        FakeMode: true,
    })
}

// テストでの使用
func TestCreateSwitch(t *testing.T) {
    caller := NewFakeCaller(t)
    switchOp := iaas.NewSwitchOp(caller)
    
    sw, err := switchOp.Create(context.Background(), "is1a", &iaas.SwitchCreateRequest{
        Name: "test-switch",
    })
    if err != nil {
        t.Fatal(err)
    }
    
    if sw.Name != "test-switch" {
        t.Errorf("Expected name 'test-switch', got %s", sw.Name)
    }
    
    if sw.ID <= 0 {
        t.Errorf("Expected positive ID, got %d", sw.ID)
    }
}
```

## 一般的な定数

```go
import "github.com/sacloud/iaas-api-go/types"

// ゾーン
"is1a"  // 石狩第1
"is1b"  // 石狩第2
"tk1a"  // 東京第1
"tk1b"  // 東京第2

// ディスクリプラン
types.DiskPlans.HDD
types.DiskPlans.SSD

// コミットメント（課金タイプ）
types.Commitments.Standard

// スコープ
types.Scopes.Shared    // 共有
types.Scopes.User      // ユーザー

// インターフェースのドライバ
interfaceDrivers.VirtIO
interfaceDrivers.E1000
```

## スタートアップスクリプト（cloud-config / UserData）

サーバー起動時にcloud-configやシェルスクリプトを実行できます。

### スタートアップスクリプト（Note）の作成

```go
import "github.com/sacloud/iaas-api-go"
	noteOp := iaas.NewNoteOp(client)

// cloud-config形式
cloudConfigContent := `#cloud-config
hostname: my-server
fqdn: my-server.example.com
packages:
  - nginx
  - git
runcmd:
  - systemctl start nginx
`

note, err := noteOp.Create(ctx, &iaas.NoteCreateRequest{
    Name:    "cloud-config-example",
    Content: cloudConfigContent,
    Class:   "cloud-config", // cloud-config, shell, yaml_kernelなど
    Tags:    types.Tags{"env:production"},
})
```

### スクリプトクラスの種類

- `cloud-config` - cloud-init形式の設定
- `shell` - シェルスクリプト
- `yaml_kernel` - YAMLカーネルパラメータ

### ディスク作成時にUserDataを設定

```go
diskOp := iaas.NewDiskOp(client)

// CreateWithConfigでディスク作成と同時にUserDataを適用
disk, err := diskOp.CreateWithConfig(ctx, "is1a",
    &iaas.DiskCreateRequest{
        Name:       "server-disk",
        SizeMB:     20 * 1024 * 1024,
        DiskPlanID: types.DiskPlans.SSD,
    },
    &iaas.DiskEditRequest{
        HostName: "my-server",
        Password: "initial-password",
        Notes: []*iaas.DiskEditNote{
            {
                ID: note.ID,  // スタートアップスクリプトのID
                Variables: map[string]interface{}{
                    "SERVER_ROLE": "web",
                    "ENV":         "production",
                },
            },
        },
        SSHKeys: []*iaas.DiskEditSSHKey{
            {PublicKey: "ssh-rsa AAAAB3..."},
        },
        DisablePWAuth: true,  // パスワード認証を無効化
    },
    false, // bootAtAvailable
    nil,   // distantFrom
    0,     // kmeKeyID
)
```

### 既存ディスクにUserDataを適用

```go
// Configメソッドで既存ディスクに設定を適用
err = diskOp.Config(ctx, "is1a", diskID, &iaas.DiskEditRequest{
    HostName:      "renamed-server",
    DisablePWAuth: true,
    Notes: []*iaas.DiskEditNote{
        {ID: noteID},
    },
    SSHKeys: []*iaas.DiskEditSSHKey{
        {PublicKey: "ssh-rsa AAAAB3..."},
    },
})
```

## 実践例：完全なCRUDフロー

```go
package main

import (
    "context"
    "log"
    "os"
    
    "github.com/sacloud/iaas-api-go"
    "github.com/sacloud/iaas-api-go/helper/power"
    "github.com/sacloud/iaas-api-go/types"
)

func main() {
    ctx := context.Background()
    
    // クライアント初期化
    client := iaas.NewClientFromEnv()
    
    // オペレーション作成
    serverOp := iaas.NewServerOp(client)
    
    // 1. 作成
    server, err := serverOp.Create(ctx, "is1a", &iaas.ServerCreateRequest{
        CPU:               1,
        MemoryMB:          1024,
        Name:              "example-server",
        Commitment:        types.Commitments.Standard,
        Generation:        types.PlanGenerations.Default,
        ConnectedSwitches: []*iaas.ConnectedSwitch{},
    })
    if err != nil {
        log.Fatal(err)
    }
    
    // 2. 起動
    if err := power.BootServer(ctx, serverOp, "is1a", server.ID); err != nil {
        log.Fatal(err)
    }
    
    // 3. 更新
    server, err = serverOp.Update(ctx, "is1a", server.ID, &iaas.ServerUpdateRequest{
        Name: "example-server-renamed",
    })
    if err != nil {
        log.Fatal(err)
    }
    
    // 4. 停止
    if err := power.ShutdownServer(ctx, serverOp, "is1a", server.ID, true); err != nil {
        log.Fatal(err)
    }
    
    // 5. 削除
    if err := serverOp.Delete(ctx, "is1a", server.ID); err != nil {
        log.Fatal(err)
    }
    
    log.Println("Complete!")
}
```