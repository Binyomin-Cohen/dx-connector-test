public with sharing virtual class MemberPageControllerBase {
    private ComponentSearchControllerBase componentController;
    
    public virtual ComponentSearchControllerBase getComponentController() {
        return componentController;
    }
    
    public virtual void setComponentController(ComponentSearchControllerBase componentController) {
        this.componentController = componentController;
    }
    
    public MemberPageControllerBase getThis() {
        return this;
    }
}