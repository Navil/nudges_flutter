'use strict';
const cors = require('cors')({origin: true});
const express = require('express');

const functions = require('firebase-functions');

const iap = require('in-app-purchase');
const serviceAccount = require("./serviceAccount.json");
const config = require('./secrets.json');
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: config.databaseURL
});

const userRef = admin.firestore().collection("users");
const chatRef = admin.database().ref("/chat");
const nodemailer = require('nodemailer');


var transporter = nodemailer.createTransport({
	service: 'gmail',
	auth: {
	  user: config.email,
	  pass: config.password
	}
  });

// Express middleware that validates Firebase ID Tokens passed in the Authorization HTTP header.
// The Firebase ID token needs to be passed as a Bearer token in the Authorization HTTP header like this:
// `Authorization: Bearer <Firebase ID Token>`.
// when decoded successfully, the ID Token content will be added as `req.user`.
const validateFirebaseIdToken = (req, res, next) => {
  //console.log('Check if request is authorized with Firebase ID token ');
	
  if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
    console.error('No Firebase ID token was passed as a Bearer token in the Authorization header.',
        'Make sure you authorize your request by providing the following HTTP header:',
        'Authorization: Bearer <Firebase ID Token>');
    res.status(403).send('Unauthorized');
    return;
  }
  const idToken = req.headers.authorization.split('Bearer ')[1];
  admin.auth().verifyIdToken(idToken).then(decodedIdToken => {
    //console.log('ID Token correctly decoded', decodedIdToken);
    req.user = decodedIdToken;
    next();
  }).catch(error => {
    console.error('Error while verifying Firebase ID token:', error);
    res.status(403).send('Unauthorized');
  });
};

const router = new express.Router();
router.use(cors);
router.use(validateFirebaseIdToken);
/*
	Params: userID, lat, lon, minAge, maxAge, maxDistance, gender (f = female, m = male, b = both)
*/
router.post('/acceptRequest', (req, res) => {
	//console.log("Calling queryPeople "+req.body.userID+";"+req.body.minAge+";"+req.body.maxAge+";"+req.body.maxDistance+";"+req.body.gender+";"+req.body.lat+";"+req.body.lon);
	//console.log("queryPeople for "+req.body.userID);
	const userId = req.body.userId;
	const friendId = req.body.friendId;
	return userRef.child(userId).child("requests").child(friendId).once("value", data => {
		if(data.val()){ //There really is a request
			return chatRef.push({users:{[userId]:new Date().toISOString(), [friendId]:new Date().toISOString()}}).then(chat => {
				const promise1 = userRef.child(userId).child("data").once('value');
				const promise2 = userRef.child(friendId).child("data").once('value');

				const promise3 = userRef.child(userId).child("friends").update({[friendId]:
					{lastActivity: new Date().toISOString(), lastMessage: "Became friends", chatId:chat.key}});
				const promise4 = userRef.child(friendId).child("friends").update({[userId]:
					{lastActivity: new Date().toISOString(), lastMessage: "Became friends", chatId:chat.key}});

				return Promise.all([promise1,promise2,promise3,promise4]).then(result => {
					const user = result[0];
					const friend = result[1];

					const payload1 = {
						data: {
							title: "nudges",
							body: user.val().firstname+" accepted your friend request.",
							"content-available": "1",
							"image": "www/assets/img/logo.png",
							event: "MATCH",
							userId: userId,
							chatId: chat.key
						}
					};

					const payload2 = {
						data: {
							title: "nudges",
							body: "You are now friends with "+friend.val().firstname+".",
							"content-available": "1",
							"image": "www/assets/img/logo.png",
							event: "MATCH",
							userId: friendId,
							chatId: chat.key
						}
					};
					let messagePromise1 = true;
					let messagePromise2 = true;

					if(friend.val().messageToken)
						messagePromise1 = admin.messaging().sendToDevice(friend.val().messageToken, payload1);
					
					if(user.val().messageToken)
						messagePromise2 = admin.messaging().sendToDevice(user.val().messageToken, payload2);

					//From now on, since they are friends, we replace the request with a simple like, to keep is simple
					let removeRequest1 = userRef.child(userId).child("requests").child(friendId).remove();
					let removeRequest2 = userRef.child(friendId).child("requests").child(userId).remove();
					
					return Promise.all([messagePromise1,messagePromise2,removeRequest1,removeRequest2]).then(()=>{
						res.status(200).send("Success");
					});
				});
			});
		}else{
			res.status(403).send("There is no pending request to accept.");	
		}
	},err => {
		console.error(err);
		res.status(400).send("There is some unknown problem.");	
	});
	
	//res.send('Hello');
});

/*
	Params: initiatorId, receiverId
*/
router.post('/removeFriend', (req, res) => {
	console.log("removeFriend");
	const promise1 = userRef.child(req.body.initiatorId).child("friends").child(req.body.receiverId).remove();
	const promise2 = userRef.child(req.body.receiverId).child("friends").child(req.body.initiatorId).remove();
	const promise3 = chatRef.child(req.body.chatId).remove();
	return Promise.all([promise1,promise2,promise3]).then(()=>{
		res.status(200).send('ok');
	});
});

router.post('/validateUpgrade', (req, res) => {
	console.log("ValidateUpgrade");
	const userId = req.body.initiatorId;
	const isAndroid = req.body.isAndroid;

	let validationType;
	let data;

	if(isAndroid){
		validationType = iap.GOOGLE;
		iap.config({ googlePublicKeyStrLive: config.googleKeyLive});
		data = { receipt: req.body.receipt, signature: req.body.signature };
	}else{
		validationType = iap.APPLE;
		iap.config({ applePassword: config.itunesSecret });
		data = req.body.receipt;
	}
	iap.setup((err) => {
		if (err) {
		  console.log("Error:"+err);
		  return false;
		} else {
		  iap.validate(validationType, data, (err, response) => {
			if (err) {
			  console.log("Error:"+err);
			  return false;
			} else {
			  if (iap.isValidated(response)) {
				const purchaseDataList = iap.getPurchaseData(response);
				return userRef.child(userId).child("data").child("isPremium").set(true).then(()=> {
					console.log("Upgrade was Validated");
					
					console.log(JSON.stringify(purchaseDataList));
					return userRef.child(userId).child("receipts").child(new Date().getTime()).set(purchaseDataList).then( ()=> {
						res.status(200).send('validated');	
						return true;
					})
					
				});
			  }
			}
		  });
		}
	});

});
exports.nudges = functions.https.onRequest(router);


exports.setupProfile = functions.auth.user().onCreate(user => {
    
    return userRef.doc(user.uid).set({images:{0:"",1:"",2:"",3:""},aboutme:"",accountStatus:0}); 
});

exports.deleteProfile = functions.auth.user().onDelete(user => {
	user.disabled = true;
	return userRef.doc(user.uid).delete(); 
});

exports.updateMembershipsOnGroupChange = functions.firestore.document('groups/{groupId}').onUpdate((change, context) => {

	if(!change.after.exists)
        return false;
        
    const newValue = change.after.data();
	var toComplete = [];

	//Update Group feed on myGroups page
	return admin.firestore().collection("groups").doc(context.params.groupId).collection("members").listDocuments().then(members => {
        members.forEach(member => {
            console.log("Updating the membership of "+member.id);
            toComplete.push(admin.firestore().collection("users").doc(member.id).collection("groups").doc(context.params.groupId).update({
                isPublic: newValue.isPublic,
                location: newValue.location,
                groupname: newValue.name,
                time: newValue.time
            }));
        })
        return Promise.all(toComplete);
    })
});

exports.deleteMembershipsOnGroupChange = functions.firestore.document('groups/{groupId}').onDelete((change, context) => {
	var toComplete = [];
	
    //Delete groups from users
	return admin.firestore().collection("groups").doc(context.params.groupId).collection("members").listDocuments().then(members => {
        members.forEach(member => {
			console.log("Updating the membership of "+member.id);
			toComplete.push(admin.firestore().collection("users").doc(member.id).collection("groups").doc(context.params.groupId).delete());
        })

        var done = false;
        //Delete subcollections
        return change.ref.listCollections().then(subCollections => {
            subCollections.forEach(subCollection => {
                subCollection.listDocuments().then(documents => {
                    documents.forEach(document => {
                        toComplete.push(document.delete());
                        if(done)
                            return Promise.all(toComplete);
                    })
                })
            })
            done = true;
        });	
    })
});
exports.recursiveDelete = functions.https.onCall((data, context) => {
    // Only allow admin users to execute this function.

    const path = data.path;
    console.log(
      `User ${context.auth.uid} has requested to delete path ${path}`
    );

    // Run a recursive delete on the given document or collection path.
    // The 'token' must be set in the functions config, and can be generated
    // at the command line by running 'firebase login:ci'.
    return firebase_tools.firestore
      .delete(path, {
        project: process.env.GCLOUD_PROJECT,
        recursive: true,
        yes: true,
        token: functions.config().fb.token
      })
      .then(() => {
        return {
          path: path 
        };
      });
  });

function deleteQueryBatch(db, query, batchSize, resolve, reject) {
  query.get()
    .then((snapshot) => {
      // When there are no documents left, we are done
      if (snapshot.size == 0) {
        return 0;
      }

      // Delete documents in a batch
      var batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      return batch.commit().then(() => {
        return snapshot.size;
      });
    }).then((numDeleted) => {
      if (numDeleted === 0) {
        resolve();
        return;
      }

      // Recurse on the next process tick, to avoid
      // exploding the stack.
      process.nextTick(() => {
        deleteQueryBatch(db, query, batchSize, resolve, reject);
      });
    })
    .catch(reject);
}

