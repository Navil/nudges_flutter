'use strict';
const cors = require('cors')({origin: true});
const express = require('express');
const bodyParser = require('body-parser');

const functions = require('firebase-functions');
const gcs = require('@google-cloud/storage')({keyFilename: './serviceAccount.json'});
const spawn = require('child-process-promise').spawn;
const path = require('path');
const os = require('os');
const fs = require('fs');
const request = require('request');
const iap = require('in-app-purchase');
const serviceAccount = require("./serviceAccount.json");
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: config.databaseURL
});

const userRef = admin.database().ref("/user");
const groupRef = admin.database().ref("/group");
const chatRef = admin.database().ref("/chat");
const defaultBucket = gcs.bucket(config.databaseURL);

const nodemailer = require('nodemailer');
const config = require('./config.json');

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


exports.notifyOnPrivateMessage = functions.database.ref('/chat/{chatId}/messages/{messageId}').onWrite((change, context) => {
    if (!change.after.exists()) {
    return false;
}

const chatId = context.params.chatId;
const sender = change.after.val().sender;

return chatRef.child(chatId).child("users").once("value").then(snapshot => {
    const payload = {
        data: {
            title: "nudges",
            body: "You got a new private message!",
            "content-available": "1",
            "image": "assets/img/notification",
            event: "PRIVATEMESSAGE",
            userId: sender
        }
    };


const updatePromises = new Array();
const messagePromises = new Array();
//update for every user
snapshot.forEach(receiver => {
    if(sender !== receiver.key){ //only triggererd once

    updatePromises.push(userRef.child(sender).child("friends").child(receiver.key).update({lastActivity:change.after.val().timestamp,lastMessage:change.after.val().content,sender:sender}));
    updatePromises.push(userRef.child(receiver.key).child("friends").child(sender).update({lastActivity:change.after.val().timestamp,lastMessage:change.after.val().content,sender:sender}));

    updatePromises.push(userRef.child(receiver.key).child("data").child("messageToken").once('value').then(token => {
        //console.log("Sending message to "+receiver.key);
        if(token.val()){
        messagePromises.push(admin.messaging().sendToDevice(token.val(), payload));
    }
}));
}
});

return Promise.all(updatePromises).then(result => {
    return Promise.all(messagePromises);
});

});
});

exports.notifyOnGroupMessage = functions.database.ref('/group/{groupId}/messages/{messageId}').onWrite((change, context) => {
    if (!change.after.exists()) {
    return false;
}

const groupId = context.params.groupId;
const sender = change.after.val().sender;

return groupRef.child(groupId).child("users").once("value").then(snapshot => {
    //console.log("1"+JSON.stringify(event.data.val()));
    const payload = {
        data: {
            title: "nudges",
            body: "You got a new group message!",
            "content-available": "1",
            "image": "www/assets/img/logo.png",
            event: "GROUPMESSAGE",
            userId: sender
        }
    };

const updatePromises = new Array();
const messagePromises = new Array();

//update for every user
snapshot.forEach(receiver => {

    updatePromises.push(userRef.child(receiver.key).child("groups").child(groupId).update({lastActivity:change.after.val().timestamp,lastMessage:change.after.val().content,sender:sender}));
if(sender !== receiver.key){
    updatePromises.push(userRef.child(receiver.key).child("data").child("messageToken").once('value').then(token => {
        //console.log("Sending message to "+receiver.key);
        if(token.val()){
        messagePromises.push(admin.messaging().sendToDevice(token.val(), payload));
    }
}));
}
});

return Promise.all(updatePromises).then(() => {
    return Promise.all(messagePromises);
});
});
});

exports.notifyOnGroupLocationChange = functions.database.ref('/group/{groupId}/data/location').onWrite((change, context) => {
    if (!change.after.exists() || (change.before.val() === change.after.val())){
    return false;
}

const groupId = context.params.groupId;

const payload = {
    data: {
        title: "nudges",
        body: change.before.val().split(",")[0]+" changed to "+change.after.val().split(",")[0]+".",
        "content-available": "1",
        "image": "www/assets/img/logo.png",
        event: "GROUPCHANGE",
        groupId: groupId
    }
};

const informPromises = new Array();
const messagePromises = new Array();

return groupRef.child(groupId).child("users").once("value").then(snapshot => {
    //update for every user	+	return admin.messaging().sendToTopic(groupId,payload);
    snapshot.forEach(receiver => {
    if(groupId !== receiver.key){
    informPromises.push(userRef.child(receiver.key).child("data").child("messageToken").once('value').then(token => {
        //console.log("Sending message to "+receiver.key);
        if(token.val()){
        messagePromises.push(admin.messaging().sendToDevice(token.val(), payload));
    }
}));
}
});
return Promise.all(informPromises).then(() => {
    return Promise.all(messagePromises);
});
});
});

exports.createGroupChat = functions.database.ref('/group/{userId}').onCreate((newSnap,context) => {
    // Only create chat, when the group didn't exist before.
    const userId = context.params.userId;

if (newSnap.exists()) {
    const promise1 = userRef.child(userId).child("groups").update({[userId]:
            {lastActivity: new Date().toISOString(), lastMessage: "Created Group",sender:userId}});
    const promise2 = groupRef.child(userId).child("users").update({[userId]:new Date().toISOString()});
    const promise3 = groupRef.child(userId).child("data").update({numFemale:0,numMale:0});
    return Promise.all([promise1,promise2,promise3]);
}else{
    return true;
}
});

exports.genderCounter = functions.database.ref('/group/{groupId}/users/{userId}').onWrite((change,context) => {
    const groupId = context.params.groupId;
const userId = context.params.userId;

return groupRef.child(groupId).child("data").once("value", data => {

    if(!data.exists())
return true;

return userRef.child(userId).child("data").child("gender").once("value",gender => {
    const ref = groupRef.child(groupId).child("data").child(gender.val()=="m"?"numMale":"numFemale");

return ref.transaction(numGender => {
    if(change.after.val() && !change.before.val())
return ((numGender || 0) + 1);
else if(!change.after.val() && change.before.val() && numGender > 0)
    return numGender - 1;
else
    return numGender;
});
});

});
});

exports.reportCounter = functions.database.ref('/user/{userId}/reports/{initiatorId}').onWrite((change,context) => {
    const userId = context.params.userId;

return userRef.child(userId).child("numReports").once("value",snapshot => {
    let numReports = snapshot.val();
if(!numReports)
    numReports = 0;
else if(numReports % 1 == 0){
    var mailOptions = {
        from: 'report@nudges.at',
        to: 'office@nudges.at',
        subject: 'User exceeded report threshold!',
        text: 'UserId: '+userId+' now has '+snapshot.val()+' reports.'
    };

    transporter.sendMail(mailOptions, (error, info) => {
        if (error) {
            console.log(error);
        }
    });
}
return userRef.child(userId).child("numReports").set(change.after.exists()?numReports+1:numReports-1)
});

});

exports.deleteGroupChat = functions.database.ref('/group/{userId}').onDelete((oldSnap,context) => {
    // Only create chat, when the group didn't exist before.
    const userId = context.params.userId;
//delete chat when there is no new data
const promises = new Array();
oldSnap.child("users").forEach(member => {
    promises.push(userRef.child(member.key).child("groups").child(userId).remove());
});
promises.push(admin.database().ref("/grouplocation").child(userId).remove());
return Promise.all(promises);
});

exports.updateThumbnail = functions.database.ref('/user/{userId}/data/images/0').onWrite((change,context) => {
    const userId = context.params.userId;

if (!change.after.exists() || !change.after.val() || change.after.val() === "") {
    return userRef.child(userId).child("data").child("thumbnail").remove();
}else{
    const uri = change.after.val();
    let cancel = false;

    userRef.child(userId).child("data").child("thumbnail").set(uri);
    console.log("Function call done! "+new Date());
    const fileName = 'temp_thumbnail_'+new Date().getTime()+'.jpeg';
    const tempFilePath = path.join(os.tmpdir(), fileName);
    const checkPromise = userRef.child(userId).child("data").child("images").child("0").on("value", newValue => {
        //console.log("Value changed");
        if(newValue.val() !== uri){
        console.log("Aborting, since value changed");
        userRef.child(userId).child("data").child("images").child("0").off("value",checkPromise);
        cancel = true;
        try{
            fs.unlinkSync(tempFilePath);
        }catch(err){

        }
    }
})

    //Download image
    // Download file from bucket.
    const download = function(uri, filename, callback){
        request.head(uri, function(err, res, body){
            request(uri).pipe(fs.createWriteStream(tempFilePath)).on('close', callback);
        });
    };

    download(uri, fileName , function(){
        //console.log('done at '+tempFilePath);
        //Scale the thumbnail

        //console.log("Download done! "+new Date());
        return spawn('convert', [tempFilePath, '-thumbnail', '100x100>', tempFilePath]).then(()=> {
            //console.log("Scale done! "+new Date());

            return defaultBucket.upload(tempFilePath,{destination: defaultBucket.file(userId+"/images/thumbnail.jpeg")}).then(data => {
                //console.log("Upload done! "+new Date());
                fs.unlinkSync(tempFilePath);

        return data[0].getSignedUrl({
            action: 'read',
            expires: '03-09-2491'
        }).then(signedUrls => {
            console.log("Thumbnail created! "+new Date());
        userRef.child(userId).child("data").child("images").child("0").off("value",checkPromise);
        return userRef.child(userId).child("data").child("thumbnail").set(signedUrls[0]);
    });

    });
    },err => {
            console.error(err)
            return false;
        });
    });

}
});

exports.setupProfile = functions.auth.user().onCreate(user => {
    //TODO: Show welcome screen
    return userRef.child(user.uid).child("data").update({images:{0:"",1:"",2:"",3:""},aboutme:"",accountStatus:0}); //TODO BETA
});

exports.cleanUp = functions.auth.user().onDelete(user => {
    //remove user ( + likes, + data)
    //remove geolocation
    //remove friends,chats and likes
    //remove group
    //remove storage
    //TODO
    const userId = user.uid;
const deletePromises = [];

//Remove friends and chats
const friendsPromise = userRef.child(userId).child("friends").once("value",friends => {
    friends.forEach(friend => {
    const friendId = friend.key;
//Remove friend
deletePromises.push(userRef.child(friendId).child("friends").child(userId).remove());
//Remove chat
deletePromises.push(chatRef.child(friend.val().chatId).remove())
//Remove friend from other end
deletePromises.push(userRef.child(userId).child("friends").child(friendId).remove());

});
});

//Remove Storage
//exec("gsutil rm gs://"+bucketName+"/"+userId+"/*", function(error,stdout,stderr){console.error(error)});
const storagePromise = defaultBucket.deleteFiles({
    prefix: userId+"/",
    force: true
});

//Remove groupmembers + group
const groupPromise = groupRef.child(userId).child("users").once("value",members => {
    members.forEach(member => {
    const memberId = member.key;
//Remove membership
deletePromises.push(userRef.child(memberId).child("groups").child(userId).remove());
});
//Delete users seperatly, so the tregered function on the server has less work
deletePromises.push(groupRef.child(userId).child("users").remove());
deletePromises.push(groupRef.child(userId).remove());
});

return Promise.all([friendsPromise,groupPromise,storagePromise]).then(()=> {
    deletePromises.push(userRef.child(userId).remove());
return Promise.all(deletePromises);
})


//return userRef.child(event.data.uid).child("data").update({images:{image1:"",image2:"",image3:"",image4:""}});
// ...
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
exports.recursiveDelete = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .https.onCall((data, context) => {
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

