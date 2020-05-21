# DOSpaces

[Vapor 3](https://vapor.codes/) Service for [DigitalOcean Spaces](https://developers.digitalocean.com/documentation/spaces/)

Simple service to easily manage files in DigitalOcean Spaces.
Uses [S3Signer](https://github.com/rausnitz/S3.git) for authentication.

* Currently supported operation: `upload`,`delete`,`list`,`keys`

### Installation (SPM)
 ```ruby
.package(url: "https://github.com/sderiu/digitalocean-spaces.git", .branch("master"))
 ```

### Usage 
```
#configure.swift

let dosconfig = DOSpaces.Config(endpoint: "YOUR_SPACE_ENDPOINT", accessKey: "ACCESS_KEY", secretKey: "SECRET_KEY", region: .euCentral1, cdn: true) #See [S3Signer](https://github.com/rausnitz/S3.git) for supported region
let dospace = try DOSpaces(dosconfig, services: &services)
services.register(dospace)
```
###### Upload
```
func uploadMyFile(_ req: Request, myFile: File) throws -> Future<String> {
    let space = try req.DOSpaces()
    return try space.upload(req, path: "your/path", file: myFile, name: "myFileName")
    //returns the uploaded file url or an empty string
}
```
###### Delete
```
return try space.delete(req, path: "your/path", name: "myFileName")
//returns status 204 
```
###### List
```
return try space.list(req)
//return xml string listing the content of the bucket
```

###### Keys
```
return try space.keys(req)
//return an array of string containing all the keys in the bucket
```
