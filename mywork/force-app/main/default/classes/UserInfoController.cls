public with sharing class UserInfoController {
    
    public String userExperience;
    
    public UserInfoController() {

    }

    public String getUserExperience() {
        return UserInfo.getUiThemeDisplayed();
    }
}
