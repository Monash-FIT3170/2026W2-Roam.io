/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Verifies the persistent Kudos/comments test activity and optional follower
 *   relationship in the development Firebase project.
 */

const { parseArgs, verifyTestActivity } = require('./seed_test_activity');

if (require.main === module) {
  verifyTestActivity(parseArgs(process.argv))
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      process.exit(0);
    })
    .catch((error) => {
      console.error('[verify_test_activity] failed:', error);
      process.exit(1);
    });
}
