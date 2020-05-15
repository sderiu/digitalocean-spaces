# DOSpaces

[Vapor 3](https://vapor.codes/) Service for [DigitalOcean Spaces](https://developers.digitalocean.com/documentation/spaces/)

Simple service to easily manage files in DigitalOcean Spaces.
Uses [S3Signer](https://github.com/rausnitz/S3.git) for authentication.

* Currently supported operation: `upload`

### Installation (SPM)
 ```ruby
.Package(url: "https://github.com/sderiu/digitalocean-spaces.git", .branch("master"))
 ```

### Usage
```
let dosconfig = DOSpaces.Config(endpoint: "YOUR_SPACE_ENDPOINT", accessKey: "ACCESS_KEY", secretKey: "SECRET_KEY", region: .euCentral1) #See [S3Signer](https://github.com/rausnitz/S3.git) for supported region
let dospace = try DOSpaces(dosconfig)
services.register(dospace)
```
###### Upload
```
func uploadMyFile(_ req: Request, myFile: File) throws -> Future<String> {
    let space = try req.DOSpaces()
    return try space.upload(req, path: "your/path", file: myFile, name: "myFileName") // File extension is auto-filled
    //returns the uploaded file url
}
```

