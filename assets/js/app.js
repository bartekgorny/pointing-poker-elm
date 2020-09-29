// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"


// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket"
// Now that you are connected, you can join channels with a topic:
let sid = document.querySelector("#session_id")
import { Elm } from "../elm/src/Session.elm"

if(sid) {

    let app = Elm.Session.init({ node: document.getElementById("session-elm-container"), flags: sid.innerText})

    let channel = socket.channel("session:" + sid.innerText, {})
    channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })
    // outgoing
    app.ports.changeNickPort.subscribe(function(nick) {
        channel.push("set_nick", { nick : nick});
    });
    app.ports.votingActionPort.subscribe(function(payload){
        channel.push("voting_action", payload)
    })
    // incoming
    channel.on("joined", payload => {
        app.ports.confirmJoinPort.send({})
    });
    channel.on("new_vote", payload => {
        app.ports.newVotePort.send(payload)
    });
    channel.on("session_state", payload => {
    console.log(payload);
        app.ports.freshStatePort.send(payload);
    });
    channel.on("showvotes", payload => {
        app.ports.showVotesPort.send(payload);
    })
}
