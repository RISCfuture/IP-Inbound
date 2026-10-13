# CloudKit schema

`schema.ckdb` is the Production schema of `iCloud.codes.tim.IP-Inbound`,
exported with `cktool`. Production builds (TestFlight and the App Store) cannot
create record types or fields, so any change to `Target` has to reach
Production before the build that carries it ships. Otherwise its records never
leave the device.

## Changing the schema

1. Write the new model to Development. Every Debug launch on a device or
   simulator signed into iCloud initializes the schema from
   `IP_InboundApp.syncedModels`, so run one once after changing the model.

2. Deploy it. In CloudKit Console, open Development and choose **Deploy Schema
   Changes**. The diff should show only additions: Production is append-only,
   and a deployed field can never be renamed or removed.

3. Export Production over `schema.ckdb` and commit it:

   ```sh
   xcrun cktool export-schema --team-id 2NFSK2WB24 \
     --container-id iCloud.codes.tim.IP-Inbound --environment production \
     --token "$(~/Repositories/certificates/bin/cloudkit-token)" \
     --output-file CloudKit/schema.ckdb
   ```

The management token lives encrypted in the certificates repository. See its
`SETUP.md`.

## How it's checked

- **`IP InboundTests/CloudKitSchemaTests`** compares `schema.ckdb` with
  `IP_InboundApp.syncedModels`. A missing record type or field, or a field of
  the wrong type, is a test warning, so a model change can be built before its
  schema is deployed.
- **The CloudKit workflow** exports Production on every push, pull request, and
  Monday, and fails unless it matches `schema.ckdb`. A failure means someone
  deployed without exporting (re-run step 3) or edited the file by hand.
- **The release workflow** runs both checks first, with the schema test strict,
  and archives nothing if either fails: a model change has to complete all three
  steps above before it ships.
