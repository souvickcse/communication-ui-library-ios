**STRUCT**

# `GroupCallOptions`

```swift
public struct GroupCallOptions
```

## Description

Options for joining a group call.

## Properties

### `communicationTokenCredential`

The token credential used for communication service authentication.

```swift
public let communicationTokenCredential: CommunicationTokenCredential
```

### `groupId`

The unique identifier for the group conversation.

```swift
public let groupId: UUID
```

### `displayName`

The display name of the local participant when joining the call.

```swift
public let displayName: String
```

## Methods

### `init`

Create an instance of a `GroupCallOptions` with options.

```swift
public init(
    communicationTokenCredential: CommunicationTokenCredential,
    groupId: UUID)
```

```swift
public init(
    communicationTokenCredential: CommunicationTokenCredential,
    groupId: UUID,
    displayName: String)
```

### Parameters
* `communicationTokenCredential` - The CommunicationTokenCredential used for communication service authentication
* `groupId` - The unique identifier for joining a specific group conversation
* `displayName` - Specify the display name of the local participant for the call