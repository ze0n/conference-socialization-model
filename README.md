# MODEL DESCRIPTION
This model is intended to simulate the coffee-brake and a socialization part of a conference. What do people do during this kind of sections? Eat, drink, and communicate. So, all of these activities are represented in the agents' behaviors.

Agent's behavior consists of wishes and current actions. Agent may 'walk', 'talk', 'listen'. Intentions are presented by 'wanna-walk', 'wanna-eat', 'wanna-talk' and 'wanna-listen' wishes. Wishes define goals of an agent. When a goal is reached an agent randomly chooses another wish (each behavior type has a corresponding probability).

As for the low-level movement model, the model incorporates the Social Forces Model (by Dirk Helbing, http://pre.aps.org/abstract/PRE/v51/i5/p42821), which is used in order to provide collision avoidance. The implementation of the SFM was taken from the "Waiting Bar Customers" model http://modelingcommons.org/browse/onemodel/3645.

Conversations are set by temporary links between talker and listeners.
As an addon, the model of infection propagation is implemented.

![promisechains](https://github.com/ze0n/conference-socialization-model/blob/master/doc/Screenshot.png)

# PURPOSE
The main purpose of the model is in use during educational master-class for students on theme of Agent-Based modeling and simulation in NetLogo.
As an example of a task, students were proposed to extend the base model with infection propagation model.

# CREDITS AND REFERENCES
The model is based on the the Social Forces Model implementation taken from Waiting Bar Customers model, which is published at http://modelingcommons.org/browse/one_model/3645

Also published at http://modelingcommons.org/browse/one_model/4300

